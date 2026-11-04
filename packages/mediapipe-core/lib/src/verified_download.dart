import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'download_asset.dart';

// Shared by build hooks and the app-side model store, so it depends on
// neither the hooks nor the code_assets package.

/// Waits before a retry. Tests replace it so they never sleep.
@visibleForTesting
Future<void> Function(Duration delay) retryWait = Future<void>.delayed;

/// Downloads [asset] atomically, reusing an existing file only if its hash matches.
/// A failed download never replaces an existing destination.
///
/// Tries each of [DownloadAsset.urls] in order. A URL whose path ends in
/// `.zip` and that has a fragment, such as `.../libraries.zip#text/x/lib.so`,
/// names that member of the archive, read with HTTP range requests without
/// the rest of the archive. Each request gets up to three attempts on a
/// connection error, a timeout or HTTP 408, 429, 500, 502, 503 or 504, and a
/// dropped download resumes where it stopped.
Future<File> downloadVerified(
  DownloadAsset asset,
  File destination, {
  http.Client? client,
  String? source,
}) async {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(asset.sha256)) {
    throw ArgumentError.value(asset.sha256, 'sha256', 'Expected SHA-256 hex');
  }
  if (await destination.exists() &&
      (await sha256.bind(destination.openRead()).first).toString() ==
          asset.sha256) {
    return destination;
  }
  await destination.parent.create(recursive: true);
  final configured = source ?? Platform.environment['MEDIAPIPE_ASSET_SOURCE'];
  final locations = configured == null || configured.isEmpty
      ? asset.urls.toList()
      : [
          configured.startsWith('http://') || configured.startsWith('https://')
              ? Uri.parse(
                  '${configured.endsWith('/') ? configured : '$configured/'}${asset.sha256}',
                ).toString()
              : File.fromUri(
                  Directory(configured).uri.resolve(asset.sha256),
                ).uri.toString(),
        ];
  final failures = <DownloadFailure>[];
  final connection = _Connection(client ?? http.Client());
  try {
    for (final location in locations) {
      final temporary = await destination.parent.createTemp('.download-');
      final partial = File.fromUri(temporary.uri.resolve('asset'));
      try {
        final uri = Uri.parse(location);
        if (uri.scheme == 'file') {
          await File.fromUri(uri).copy(partial.path);
        } else if (uri.path.endsWith('.zip') && uri.fragment.isNotEmpty) {
          await connection.zipMember(
            uri.removeFragment(),
            Uri.decodeComponent(uri.fragment),
            partial,
            File.fromUri(temporary.uri.resolve('compressed')),
          );
        } else {
          await connection.file(uri, partial);
        }
        final digest = (await sha256.bind(partial.openRead()).first).toString();
        if (digest != asset.sha256) {
          throw StateError(
            'SHA-256 mismatch: expected ${asset.sha256}, received $digest',
          );
        }
        await partial.rename(destination.path);
        return destination;
      } catch (error) {
        failures.add(DownloadFailure(location, error.toString()));
      } finally {
        await temporary.delete(recursive: true);
      }
    }
    throw DownloadException(failures);
  } finally {
    if (client == null) connection.client.close();
  }
}

const _attempts = 3;
const _timeout = Duration(seconds: 60);
const _transientStatus = {408, 429, 500, 502, 503, 504};

/// A failure the same request may repeat.
final class _Retry implements Exception {
  _Retry(this.error, [this.after]);

  final Object error;

  /// The host's `Retry-After`, when it gave one.
  final Duration? after;
}

/// A request that failed on every attempt.
final class _Exhausted implements Exception {
  _Exhausted(this.error);

  final Object error;

  @override
  String toString() => '$error, after $_attempts attempts';
}

/// The first and last byte of a 206 response, and the full size.
typedef _ContentRange = ({int first, int last, int total});

_ContentRange? _contentRange(http.BaseResponse response) {
  final match = RegExp(
    r'^bytes (\d+)-(\d+)/(\d+)$',
  ).firstMatch(response.headers['content-range'] ?? '');
  if (match == null) return null;
  return (
    first: int.parse(match[1]!),
    last: int.parse(match[2]!),
    total: int.parse(match[3]!),
  );
}

/// What a resumed request names so the host sends the rest of the same
/// file, or all of a changed one: a strong ETag, else the modification date.
String? _validator(http.BaseResponse response) {
  final etag = response.headers['etag'];
  if (etag != null && !etag.startsWith('W/')) return etag;
  return response.headers['last-modified'];
}

/// A random wait up to 1 s × 2^[attempt], at most 30 s (full jitter).
Duration _backoff(int attempt) =>
    Duration(milliseconds: Random().nextInt(min(30000, 1000 << attempt) + 1));

/// `Retry-After` in seconds, at most 30 s. An HTTP date falls back to the
/// backoff.
Duration? _retryAfter(String? value) => switch (int.tryParse(value ?? '')) {
  final seconds? when seconds >= 0 => Duration(seconds: min(seconds, 30)),
  _ => null,
};

/// Drops [response]'s body, ignoring a failure to read it.
Future<void> _discard(http.StreamedResponse response) =>
    response.stream.drain<void>().catchError((Object _) {});

final class _Connection {
  _Connection(this.client);

  final http.Client client;

  /// Runs [attempt] until it succeeds, repeating what it marks [_Retry].
  Future<T> _retrying<T>(Future<T> Function() attempt) async {
    for (var number = 1; ; number++) {
      try {
        return await attempt();
      } on _Retry catch (retry) {
        if (number == _attempts) throw _Exhausted(retry.error);
        await retryWait(retry.after ?? _backoff(number));
      }
    }
  }

  /// One GET for [uri] that answered 200 or 206.
  Future<http.StreamedResponse> _send(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final http.StreamedResponse response;
    try {
      response = await client
          .send(http.Request('GET', uri)..headers.addAll(headers))
          .timeout(_timeout);
    } on Exception catch (error) {
      throw _Retry(error);
    }
    final status = response.statusCode;
    if (status == 200 || status == 206) return response;
    await _discard(response);
    final error = HttpException('HTTP $status', uri: uri);
    if (_transientStatus.contains(status)) {
      throw _Retry(error, _retryAfter(response.headers['retry-after']));
    }
    throw error;
  }

  /// [response]'s range, failing when it is not a 206 starting at [first]
  /// and ending at [last] (either one null to accept any).
  Future<_ContentRange> _expectRange(
    http.StreamedResponse response,
    Uri uri,
    int? first,
    int? last,
  ) async {
    final range = response.statusCode == 206 ? _contentRange(response) : null;
    if (range == null ||
        (first != null && range.first != first) ||
        (last != null && range.last != last)) {
      await _discard(response);
      throw HttpException(
        'HTTP ${response.statusCode} '
        '${response.headers['content-range'] ?? 'without Content-Range'} '
        'for bytes ${first ?? ''}-${last ?? ''}: the host ignored the range '
        'or the file changed',
        uri: uri,
      );
    }
    return range;
  }

  /// Writes [response]'s body to [file], after what it holds when [append].
  /// A dropped or stalled body is retried.
  Future<void> _write(
    http.StreamedResponse response,
    File file, {
    required bool append,
  }) async {
    final sink = file.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    try {
      await sink.addStream(response.stream.timeout(_timeout));
    } catch (error) {
      await sink.close().catchError((Object _) {});
      if (error is FileSystemException || error is! Exception) rethrow;
      throw _Retry(error);
    }
    await sink.close();
  }

  /// Downloads [uri] to [file], resuming after a drop when the host named a
  /// validator.
  Future<void> file(Uri uri, File file) {
    String? validator;
    return _retrying(() async {
      final received = await file.exists() ? await file.length() : 0;
      final resume = received > 0 && validator != null;
      final response = await _send(uri, {
        if (resume) 'range': 'bytes=$received-',
        if (resume) 'if-range': validator!,
      });
      if (response.statusCode == 206) {
        await _expectRange(response, uri, resume ? received : 0, null);
      } else {
        validator = _validator(response);
      }
      await _write(response, file, append: response.statusCode == 206);
    });
  }

  /// [uri]'s bytes [first] to [last], or its last `-first` bytes when [first]
  /// is negative, with the response's range and validator.
  Future<(Uint8List, _ContentRange, String?)> _bytes(
    Uri uri,
    int first,
    int? last,
    String? validator,
  ) => _retrying(() async {
    final response = await _send(uri, {
      'range': first < 0 ? 'bytes=$first' : 'bytes=$first-$last',
      'if-range': ?validator,
    });
    final range = await _expectRange(
      response,
      uri,
      first < 0 ? null : first,
      first < 0 ? null : last,
    );
    try {
      return (
        await response.stream.toBytes().timeout(_timeout),
        range,
        _validator(response),
      );
    } on Exception catch (error) {
      throw _Retry(error);
    }
  });

  /// Bytes [first] to [last] of [uri] into [file], resuming after a drop.
  Future<void> _range(
    Uri uri,
    File file,
    int first,
    int last,
    String? validator,
  ) => _retrying(() async {
    final received = await file.exists() ? await file.length() : 0;
    final response = await _send(uri, {
      'range': 'bytes=${first + received}-$last',
      'if-range': ?validator,
    });
    await _expectRange(response, uri, first + received, last);
    await _write(response, file, append: true);
    if (await file.length() != last - first + 1) {
      throw _Retry(HttpException('The range ended early', uri: uri));
    }
  });

  /// Writes [member] of the zip archive at [uri] to [file], reading only the
  /// archive's directory and that member, through [compressed].
  Future<void> zipMember(
    Uri uri,
    String member,
    File file,
    File compressed,
  ) async {
    // The end of central directory record, its comment of up to 64 KiB, and
    // the Zip64 locator and record before it.
    final (tail, tailRange, validator) = await _bytes(uri, -65633, null, null);
    final directory = _ZipDirectory.read(tail, tailRange.first, uri);
    final listing = directory.offset >= tailRange.first
        ? Uint8List.sublistView(
            tail,
            directory.offset - tailRange.first,
            directory.offset - tailRange.first + directory.size,
          )
        : (await _bytes(
            uri,
            directory.offset,
            directory.offset + directory.size - 1,
            validator,
          )).$1;
    final entry = _ZipEntry.find(listing, member, uri);
    final (header, _, _) = await _bytes(
      uri,
      entry.offset,
      entry.offset + 29,
      validator,
    );
    final data = ByteData.sublistView(header);
    if (header.length != 30 || data.getUint32(0, Endian.little) != 0x04034b50) {
      throw FormatException('$uri: no local header for $member');
    }
    final start =
        entry.offset +
        30 +
        data.getUint16(26, Endian.little) +
        data.getUint16(28, Endian.little);
    if (entry.compressedSize > 0) {
      await _range(
        uri,
        compressed,
        start,
        start + entry.compressedSize - 1,
        validator,
      );
    } else {
      await compressed.writeAsBytes(const []);
    }
    switch (entry.method) {
      case 0:
        await compressed.rename(file.path);
      case 8:
        await compressed
            .openRead()
            .transform(ZLibDecoder(raw: true))
            .pipe(file.openWrite());
      default:
        throw FormatException(
          '$uri: $member uses zip compression method ${entry.method}',
        );
    }
    if (await file.length() != entry.size) {
      throw FormatException(
        '$uri: $member is ${await file.length()} bytes, not ${entry.size}',
      );
    }
  }
}

/// Where a zip archive's central directory is.
final class _ZipDirectory {
  const _ZipDirectory(this.offset, this.size);

  /// Finds the end of central directory record in [tail], the archive's
  /// bytes from [tailStart], and the Zip64 record when the archive has one.
  factory _ZipDirectory.read(Uint8List tail, int tailStart, Uri uri) {
    final data = ByteData.sublistView(tail);
    for (var at = tail.length - 22; at >= 0; at--) {
      if (data.getUint32(at, Endian.little) != 0x06054b50) continue;
      final size = data.getUint32(at + 12, Endian.little);
      final offset = data.getUint32(at + 16, Endian.little);
      if (size != 0xffffffff && offset != 0xffffffff) {
        return _ZipDirectory(offset, size);
      }
      // Zip64: the locator just before the record points to the Zip64 record.
      final locator = at - 20;
      if (locator >= 0 &&
          data.getUint32(locator, Endian.little) == 0x07064b50) {
        final record = data.getUint64(locator + 8, Endian.little) - tailStart;
        if (record >= 0 &&
            record + 56 <= tail.length &&
            data.getUint32(record, Endian.little) == 0x06064b50) {
          return _ZipDirectory(
            data.getUint64(record + 48, Endian.little),
            data.getUint64(record + 40, Endian.little),
          );
        }
      }
      break;
    }
    throw FormatException('$uri: no readable zip central directory');
  }

  final int offset;
  final int size;
}

/// One member of a zip archive, from its central directory entry.
final class _ZipEntry {
  const _ZipEntry(this.method, this.compressedSize, this.size, this.offset);

  /// [member]'s entry in the central directory [listing].
  factory _ZipEntry.find(Uint8List listing, String member, Uri uri) {
    final data = ByteData.sublistView(listing);
    var at = 0;
    while (at + 46 <= listing.length &&
        data.getUint32(at, Endian.little) == 0x02014b50) {
      final nameLength = data.getUint16(at + 28, Endian.little);
      final extraLength = data.getUint16(at + 30, Endian.little);
      final commentLength = data.getUint16(at + 32, Endian.little);
      final name = String.fromCharCodes(listing, at + 46, at + 46 + nameLength);
      if (name == member) {
        if (data.getUint16(at + 8, Endian.little) & 1 != 0) {
          throw FormatException('$uri: $member is encrypted');
        }
        var size = data.getUint32(at + 24, Endian.little);
        var compressedSize = data.getUint32(at + 20, Endian.little);
        var offset = data.getUint32(at + 42, Endian.little);
        // Zip64 holds, in this order, each of these fields at its limit.
        var extra = at + 46 + nameLength;
        final end = extra + extraLength;
        while (extra + 4 <= end) {
          final id = data.getUint16(extra, Endian.little);
          final length = data.getUint16(extra + 2, Endian.little);
          if (id == 1) {
            var field = extra + 4;
            int next() {
              final value = data.getUint64(field, Endian.little);
              field += 8;
              return value;
            }

            if (size == 0xffffffff) size = next();
            if (compressedSize == 0xffffffff) compressedSize = next();
            if (offset == 0xffffffff) offset = next();
          }
          extra += 4 + length;
        }
        return _ZipEntry(
          data.getUint16(at + 10, Endian.little),
          compressedSize,
          size,
          offset,
        );
      }
      at += 46 + nameLength + extraLength + commentLength;
    }
    throw FormatException('$uri has no $member');
  }

  final int method;
  final int compressedSize;
  final int size;
  final int offset;
}

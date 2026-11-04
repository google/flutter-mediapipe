import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_core/src/verified_download.dart' show retryWait;
import 'package:test/test.dart';

const _primary = 'https://primary.invalid/runtime.so';
const _mirror = 'https://mirror.invalid/runtime.so';
const _archive = 'https://primary.invalid/libraries.zip';

/// [body], or the part a `Range` header asks for, as a host that honors
/// ranges serves it.
http.StreamedResponse _serve(
  http.BaseRequest request,
  List<int> body, {
  Stream<List<int>> Function(List<int> bytes)? stream,
}) {
  final headers = {'etag': '"v1"'};
  var status = 200;
  var bytes = body;
  final range = RegExp(
    r'^bytes=(\d*)-(\d*)$',
  ).firstMatch(request.headers['range'] ?? '');
  if (range != null) {
    final first = range[1]!.isEmpty
        ? max(0, body.length - int.parse(range[2]!))
        : int.parse(range[1]!);
    final last = range[1]!.isEmpty || range[2]!.isEmpty
        ? body.length - 1
        : min(int.parse(range[2]!), body.length - 1);
    status = 206;
    bytes = body.sublist(first, last + 1);
    headers['content-range'] = 'bytes $first-$last/${body.length}';
  }
  return http.StreamedResponse(
    stream?.call(bytes) ?? Stream.value(bytes),
    status,
    headers: headers,
  );
}

/// The first [count] bytes of [bytes], then a dropped connection.
Stream<List<int>> _dropAfter(List<int> bytes, int count) async* {
  yield bytes.sublist(0, count);
  throw http.ClientException('Connection reset');
}

void main() {
  late Directory directory;
  late File destination;
  late List<Duration> waits;
  final bytes = List<int>.generate(200000, (i) => (i * 7 + i ~/ 13) % 256);
  final digest = sha256.convert(bytes).toString();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mediapipe-retry-test-');
    destination = File.fromUri(directory.uri.resolve('runtime.so'));
    waits = [];
    final wait = retryWait;
    retryWait = (delay) async => waits.add(delay);
    addTearDown(() => retryWait = wait);
  });
  tearDown(() => directory.delete(recursive: true));

  Future<File> download(
    MockClient client, {
    String url = _primary,
    List<String> mirrors = const [],
    String? sha256,
  }) => downloadVerified(
    DownloadAsset(url: url, sha256: sha256 ?? digest, mirrors: mirrors),
    destination,
    client: client,
  );

  Matcher failsWith(List<Matcher> reasons) => throwsA(
    isA<DownloadException>().having(
      (error) => [for (final failure in error.failures) failure.reason],
      'reasons',
      reasons,
    ),
  );

  group('retries', () {
    test('a transient status, after a jittered backoff', () async {
      var requests = 0;
      final client = MockClient.streaming((request, _) async {
        if (++requests == 1) {
          return http.StreamedResponse(const Stream.empty(), 503);
        }
        return _serve(request, bytes);
      });
      expect(await (await download(client)).readAsBytes(), bytes);
      expect(requests, 2);
      expect(waits, [lessThanOrEqualTo(const Duration(seconds: 2))]);
    });

    test("Retry-After's seconds, capped at 30", () async {
      var requests = 0;
      final client = MockClient.streaming((request, _) async {
        return switch (++requests) {
          1 => http.StreamedResponse(
            const Stream.empty(),
            429,
            headers: {'retry-after': '7'},
          ),
          2 => http.StreamedResponse(
            const Stream.empty(),
            503,
            headers: {'retry-after': '120'},
          ),
          _ => _serve(request, bytes),
        };
      });
      await download(client);
      expect(waits, [const Duration(seconds: 7), const Duration(seconds: 30)]);
    });

    test('a connection error', () async {
      var requests = 0;
      final client = MockClient.streaming((request, _) async {
        if (++requests == 1) throw const SocketException('Connection refused');
        return _serve(request, bytes);
      });
      await download(client);
      expect(requests, 2);
    });

    test('three times, then moves to the mirror', () async {
      final hosts = <String>[];
      final client = MockClient.streaming((request, _) async {
        hosts.add(request.url.host);
        return request.url.host == 'primary.invalid'
            ? http.StreamedResponse(const Stream.empty(), 502)
            : _serve(request, bytes);
      });
      expect(
        await (await download(client, mirrors: [_mirror])).readAsBytes(),
        bytes,
      );
      expect(hosts, [...List.filled(3, 'primary.invalid'), 'mirror.invalid']);
      expect(waits, hasLength(2));
    });

    test('and reports the attempts when every host fails', () async {
      final client = MockClient((_) async => http.Response('', 504));
      await expectLater(
        download(client),
        failsWith([allOf(contains('HTTP 504'), contains('after 3 attempts'))]),
      );
      expect(await directory.list().isEmpty, isTrue);
    });

    test('not a missing file, which moves to the mirror at once', () async {
      final hosts = <String>[];
      final client = MockClient.streaming((request, _) async {
        hosts.add(request.url.host);
        return request.url.host == 'primary.invalid'
            ? http.StreamedResponse(const Stream.empty(), 404)
            : _serve(request, bytes);
      });
      await download(client, mirrors: [_mirror]);
      expect(hosts, ['primary.invalid', 'mirror.invalid']);
      expect(waits, isEmpty);
    });

    test('not a digest mismatch, which moves to the mirror at once', () async {
      final hosts = <String>[];
      final client = MockClient.streaming((request, _) async {
        hosts.add(request.url.host);
        return _serve(
          request,
          request.url.host == 'primary.invalid' ? [1, 2, 3] : bytes,
        );
      });
      await download(client, mirrors: [_mirror]);
      expect(hosts, ['primary.invalid', 'mirror.invalid']);
    });
  });

  group('a dropped download', () {
    test('resumes from the received bytes with If-Range', () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient.streaming((request, _) async {
        requests.add(request);
        return _serve(
          request,
          bytes,
          stream: requests.length == 1
              ? (body) => _dropAfter(body, 50000)
              : null,
        );
      });
      expect(await (await download(client)).readAsBytes(), bytes);
      expect(requests[1].headers['range'], 'bytes=50000-');
      expect(requests[1].headers['if-range'], '"v1"');
    });

    test('restarts when the host sends the whole file again', () async {
      var requests = 0;
      final client = MockClient.streaming((request, _) async {
        final response = _serve(
          http.Request('GET', request.url),
          bytes,
          stream: ++requests == 1 ? (body) => _dropAfter(body, 50000) : null,
        );
        return response;
      });
      expect(await (await download(client)).readAsBytes(), bytes);
    });
  });

  group('a zip member', () {
    final stored = List<int>.generate(70000, (i) => i * 31 % 251);
    final archive = ZipEncoder().encodeBytes(
      Archive()
        ..add(ArchiveFile.bytes('text/linux_x86_64/libtext.so', bytes))
        ..add(
          ArchiveFile.bytes('text/ios_arm64/Text.framework.zip', stored)
            ..compression = CompressionType.none,
        ),
    );

    test('is read with ranges and inflated', () async {
      final ranges = <String?>[];
      final client = MockClient.streaming((request, _) async {
        ranges.add(request.headers['range']);
        return _serve(request, archive);
      });
      expect(
        await (await download(
          client,
          url: '$_archive#text/linux_x86_64/libtext.so',
        )).readAsBytes(),
        bytes,
      );
      expect(ranges, everyElement(isNotNull));
      expect(ranges.first, startsWith('bytes=-'));
    });

    test('is read as is when stored', () async {
      final client = MockClient.streaming(
        (request, _) async => _serve(request, archive),
      );
      expect(
        await (await download(
          client,
          url: '$_archive#text/ios_arm64/Text.framework.zip',
          sha256: sha256.convert(stored).toString(),
        )).readAsBytes(),
        stored,
      );
    });

    // tool/pin_nightly.py --generation pins one generation of Google's
    // archive, which a later upload to the same name does not replace.
    test("keeps the URL's query, such as a generation, on every range", () async {
      final requests = <(Uri, String?)>[];
      final client = MockClient.streaming((request, _) async {
        requests.add((request.url, request.headers['range']));
        return _serve(request, archive);
      });
      expect(
        await (await download(
          client,
          url:
              '$_archive?generation=1792585037995595#text/linux_x86_64/libtext.so',
        )).readAsBytes(),
        bytes,
      );
      expect(requests, hasLength(greaterThanOrEqualTo(3)));
      for (final (url, range) in requests) {
        expect(url.toString(), '$_archive?generation=1792585037995595');
        expect(range, isNotNull);
      }
    });

    test('resumes a dropped range', () async {
      final ranges = <String>[];
      var dropped = false;
      final client = MockClient.streaming((request, _) async {
        final range = request.headers['range']!;
        ranges.add(range);
        // The member's bytes: neither the directory nor the 30-byte local
        // header.
        final bounds = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range);
        final drop =
            !dropped &&
            bounds != null &&
            int.parse(bounds[2]!) - int.parse(bounds[1]!) >= 30;
        if (drop) dropped = true;
        return _serve(
          request,
          archive,
          stream: drop ? (body) => _dropAfter(body, 1000) : null,
        );
      });
      await download(client, url: '$_archive#text/linux_x86_64/libtext.so');
      final resumed = RegExp(r'^bytes=(\d+)-').firstMatch(ranges.last)!;
      final started = RegExp(
        r'^bytes=(\d+)-',
      ).firstMatch(ranges[ranges.length - 2])!;
      expect(int.parse(resumed[1]!) - int.parse(started[1]!), 1000);
    });

    test('reads a central directory outside the tail', () async {
      final padded = Archive();
      for (var i = 0; i < 1500; i++) {
        padded.add(ArchiveFile.string('padding/file-$i-of-the-directory', ''));
      }
      padded.add(ArchiveFile.bytes('text/linux_x86_64/libtext.so', bytes));
      final large = ZipEncoder().encodeBytes(padded);
      final client = MockClient.streaming(
        (request, _) async => _serve(request, large),
      );
      expect(
        await (await download(
          client,
          url: '$_archive#text/linux_x86_64/libtext.so',
        )).readAsBytes(),
        bytes,
      );
    });

    test('moves to the mirror at once when the host ignores ranges', () async {
      final hosts = <String>[];
      final client = MockClient.streaming((request, _) async {
        hosts.add(request.url.host);
        return request.url.host == 'primary.invalid'
            ? http.StreamedResponse(Stream.value(archive), 200)
            : _serve(request, bytes);
      });
      await download(
        client,
        url: '$_archive#text/linux_x86_64/libtext.so',
        mirrors: [_mirror],
      );
      expect(hosts, ['primary.invalid', 'mirror.invalid']);
    });

    test('names a member the archive lacks', () async {
      final client = MockClient.streaming(
        (request, _) async => _serve(request, archive),
      );
      await expectLater(
        download(client, url: '$_archive#text/missing.so'),
        failsWith([contains('has no text/missing.so')]),
      );
    });
  });
}

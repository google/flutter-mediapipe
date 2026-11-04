import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// A family's pinned browser runtime, from its `assets/runtime.json`.
final class WebRuntimePin {
  /// Reads a pin, rejecting file names that could leave the output folder.
  factory WebRuntimePin.fromJson(Map<String, Object?> json) {
    final package = json['package'];
    final version = json['version'];
    final integrity = json['integrity'];
    final files = json['files'];
    final digests = json['sha384'];
    if (package is! String ||
        !RegExp(r'^@mediapipe/tasks-[a-z]+$').hasMatch(package) ||
        version is! String ||
        !RegExp(
          r'^\d+\.\d+\.\d+(-[0-9A-Za-z]+(\.[0-9A-Za-z]+)*)?$',
        ).hasMatch(version) ||
        integrity is! String ||
        files is! List ||
        files.isEmpty ||
        digests is! Map ||
        digests.length != files.length ||
        files.any(
          (file) =>
              file is! String ||
              !RegExp(
                r'^[a-z0-9_]+(/[a-z0-9_]+)?\.(m?js|wasm)$',
              ).hasMatch(file),
        ) ||
        files.any(
          (file) =>
              digests[file] is! String ||
              !RegExp(r'^[A-Za-z0-9+/]{64}$').hasMatch(digests[file] as String),
        )) {
      throw FormatException('Invalid MediaPipe web runtime pin: $json');
    }
    return WebRuntimePin._(
      package,
      version,
      integrity,
      files.cast<String>(),
      digests.cast<String, String>(),
    );
  }

  const WebRuntimePin._(
    this.package,
    this.version,
    this.integrity,
    this.files,
    this.sha384,
  );

  /// npm package, such as `@mediapipe/tasks-vision`.
  final String package;

  /// Pinned npm version, a release or a prerelease such as `1.2.0-rc.20261018`.
  final String version;

  /// Base64 SHA-512 of the npm tarball, as npm's `integrity` records it.
  final String integrity;

  /// Files the family's worker loads, relative to the package root.
  final List<String> files;

  /// Base64 SHA-384 of each file, computed from the checked npm tarball.
  final Map<String, String> sha384;

  /// Where the runtime lives under an npm-style root, as the worker asks.
  String get directory => '$package@$version/';

  /// The tarball in the npm registry at [registry].
  Uri tarball(Uri registry) =>
      registry.resolve('$package/-/${package.split('/').last}-$version.tgz');
}

/// Downloads [pin]'s npm tarball, checks its integrity and writes the files
/// its worker loads to `<output>/<package>@<version>/`, replacing that folder
/// only once every file is in place.
Future<Directory> hostWebRuntime(
  WebRuntimePin pin,
  Directory output, {
  http.Client? client,
}) async {
  final entries = await _verifiedEntries(pin, client: client);
  final target = Directory.fromUri(output.uri.resolve(pin.directory));
  await target.parent.create(recursive: true);
  final staging = await target.parent.createTemp('.staging-');
  try {
    for (final name in pin.files) {
      final entry = entries['package/$name'];
      if (entry == null) {
        throw StateError('${pin.package}@${pin.version} has no $name.');
      }
      final content = entry.readBytes()!;
      if (base64.encode(sha384.convert(content).bytes) != pin.sha384[name]) {
        throw StateError('${pin.package}@${pin.version} has an invalid $name.');
      }
      final file = File.fromUri(staging.uri.resolve(name));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(content);
    }
    if (await target.exists()) await target.delete(recursive: true);
    await staging.rename(target.path);
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
  return target;
}

/// Computes file pins from the npm tarball after checking its SRI digest.
Future<Map<String, String>> webRuntimeHashes(
  WebRuntimePin pin, {
  http.Client? client,
}) async {
  final entries = await _verifiedEntries(pin, client: client);
  return {
    for (final name in pin.files)
      name: base64.encode(
        sha384
            .convert(
              entries['package/$name']?.readBytes() ??
                  (throw StateError(
                    '${pin.package}@${pin.version} has no $name.',
                  )),
            )
            .bytes,
      ),
  };
}

Future<Map<String, ArchiveFile>> _verifiedEntries(
  WebRuntimePin pin, {
  http.Client? client,
}) async {
  final url = pin.tarball(Uri.parse('https://registry.npmjs.org/'));
  final effective = client ?? http.Client();
  final http.Response response;
  try {
    response = await effective.get(url);
  } finally {
    if (client == null) effective.close();
  }
  if (response.statusCode != 200) {
    throw HttpException('HTTP ${response.statusCode}', uri: url);
  }
  final bytes = response.bodyBytes;
  if (base64.encode(sha512.convert(bytes).bytes) != pin.integrity) {
    throw StateError(
      '${pin.package}@${pin.version} from $url fails its '
      'pinned npm integrity check.',
    );
  }
  final entries = {
    for (final entry in TarDecoder().decodeBytes(
      GZipDecoder().decodeBytes(bytes),
    ))
      if (entry.isFile) entry.name: entry,
  };
  return entries;
}

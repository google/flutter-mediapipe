import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_core/src/native_assets/reference_wheels.dart';

/// Google's pinned official wheel on this host, from core's reference table.
({String runtime, String library, String wheel})? officialTextRuntime() {
  final wheel = referenceWheel(Abi.current().toString().replaceFirst('_', '/'));
  return wheel == null
      ? null
      : (
          runtime: 'mediapipe==${wheel.version}',
          library: wheel.librarySha256,
          wheel: wheel.wheelSha256,
        );
}

/// CI compares against Google's pinned CPU runtime on the same host.
/// Missing or modified oracle files fail instead of falling back to a baseline.
Map<String, dynamic> loadClassicTextReference({String? directory}) {
  final baselineBytes = File(
    'test/fixtures/classic_text/official_reference.json',
  ).readAsBytesSync();
  final baseline =
      jsonDecode(utf8.decode(baselineBytes)) as Map<String, dynamic>;
  final override =
      directory ?? Platform.environment['MEDIAPIPE_CLASSIC_TEXT_REFERENCE_DIR'];
  if (override == null) return baseline;
  final root = Directory(override).absolute.uri;
  final bytes = File.fromUri(
    root.resolve('official_reference.json'),
  ).readAsBytesSync();
  final reference = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  final receipt =
      jsonDecode(
            File.fromUri(root.resolve('provenance.json')).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final host = officialTextRuntime();
  if (host == null ||
      receipt['source'] != 'official-python-api' ||
      receipt['runtime'] != host.runtime ||
      receipt['delegate'] != 'CPU' ||
      receipt['library_sha256'] != host.library ||
      receipt['wheel_sha256'] != host.wheel ||
      receipt['reference_sha256'] != sha256.convert(bytes).toString() ||
      receipt['baseline_sha256'] != sha256.convert(baselineBytes).toString() ||
      reference['runtime'] != host.runtime ||
      reference['library_sha256'] != host.library ||
      [
        'delegate',
        'models',
        'abi',
      ].any((key) => jsonEncode(reference[key]) != jsonEncode(baseline[key]))) {
    throw StateError('Invalid same-host official classic text reference');
  }
  return reference;
}

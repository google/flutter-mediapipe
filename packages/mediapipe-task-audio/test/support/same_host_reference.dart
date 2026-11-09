import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_core/src/native_assets/reference_wheels.dart'
    show ReferenceWheel, referenceWheel;

/// Google's results on this host when CI prepared them with
/// tool/prepare_audio_reference.py into MEDIAPIPE_AUDIO_REFERENCE_DIR (or
/// tool/prepare_speech_reference.py into the [environment] named), else the checked-in macOS reference
/// `test/fixtures/<file>`. A missing or
/// modified same-host reference fails instead of falling back: its receipt,
/// `provenance.json`, must name Google's pinned wheel and library for this
/// host ([wheel]'s row, core's `referenceWheels` by default) and both files'
/// digests, as `<prefix>reference_sha256` and `<prefix>baseline_sha256`,
/// and the reference must keep the baseline's models and the keys of its
/// [cases] (`clips`, or `cases` for streams).
Map<String, dynamic> loadSameHostReference(
  String file, {
  required String prefix,
  required String cases,
  String environment = 'MEDIAPIPE_AUDIO_REFERENCE_DIR',
  ReferenceWheel? Function(String target) wheel = referenceWheel,
}) {
  final baselineBytes = File('test/fixtures/$file').readAsBytesSync();
  final baseline =
      jsonDecode(utf8.decode(baselineBytes)) as Map<String, dynamic>;
  final directory = Platform.environment[environment];
  if (directory == null) return baseline;
  final root = Directory(directory).absolute.uri;
  final bytes = File.fromUri(root.resolve(file)).readAsBytesSync();
  final reference = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  final receipt =
      jsonDecode(
            File.fromUri(root.resolve('provenance.json')).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final pin = wheel(Abi.current().toString().replaceFirst('_', '/'));
  final runtime = 'mediapipe==${pin?.version}';
  if (pin == null ||
      receipt['source'] != 'official-python-api' ||
      receipt['runtime'] != runtime ||
      receipt['library_sha256'] != pin.librarySha256 ||
      receipt['wheel_sha256'] != pin.wheelSha256 ||
      receipt['${prefix}reference_sha256'] !=
          sha256.convert(bytes).toString() ||
      receipt['${prefix}baseline_sha256'] !=
          sha256.convert(baselineBytes).toString() ||
      reference['runtime'] != runtime ||
      reference['model_sha256'] != baseline['model_sha256'] ||
      jsonEncode(reference['models']) != jsonEncode(baseline['models']) ||
      jsonEncode((reference[cases] as Map).keys.toList()) !=
          jsonEncode((baseline[cases] as Map).keys.toList())) {
    throw StateError('Invalid same-host official audio reference: $file');
  }
  return reference;
}

/// Generates a family's bindings from Google's headers with the family's
/// `ffigen.yaml`. Run it from the family's package:
/// `dart ../mediapipe-core/tool/generate_bindings.dart [config]`.
library;

import 'dart:io';

/// Google's unmodified MediaPipe C API headers, which core vendors once for
/// every family; see packages/mediapipe-core/native/README.md.
const _headers = '../mediapipe-core/native/include';

Future<void> main(List<String> arguments) async {
  // ffigen 21 does not visit C++ LinkageSpec cursors. Remove only the enclosing
  // extern-C blocks in temporary copies; every ABI declaration stays identical.
  await for (final entry in Directory(_headers).list(recursive: true)) {
    if (entry is! File || !entry.path.endsWith('.h')) continue;
    final destination = File(
      entry.path.replaceFirst('$_headers/', 'build/ffigen/'),
    );
    await destination.parent.create(recursive: true);
    final source = await entry.readAsString();
    await destination.writeAsString(
      source
          .replaceAll('extern "C" {', '')
          .replaceAll(
            RegExp(r'^\}  // extern (?:"C"|C).*$', multiLine: true),
            '',
          ),
    );
  }
  final sdk = await Process.run('xcrun', ['--show-sdk-path']);
  if (sdk.exitCode != 0) {
    throw StateError('Xcode is required to regenerate the bindings.');
  }
  final path = (sdk.stdout as String).trim();
  final process = await Process.start(Platform.resolvedExecutable, [
    'run',
    'ffigen',
    '--config=${arguments.isEmpty ? 'ffigen.yaml' : arguments.single}',
    '--compiler-opts',
    '-isystem "$path/usr/include/c++/v1"',
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await process.exitCode;
}

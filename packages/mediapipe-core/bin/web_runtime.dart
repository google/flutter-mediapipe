import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:mediapipe_core/src/model_bundler.dart' show bundlableFamilies;
import 'package:mediapipe_core/src/web_runtime_host.dart';

final _families = bundlableFamilies.keys;

/// Copies Google's pinned, verified browser runtimes into a folder the app
/// serves, for every task family the app depends on. Run from the app root:
///
///     dart run mediapipe_core:web_runtime web/mediapipe
///
/// then set `MediaPipeWebRuntime.baseUrl = 'mediapipe/'` before creating the
/// first task.
Future<void> main(List<String> arguments) async {
  if (arguments.length == 2 && arguments.first == '--hashes') {
    final pin = WebRuntimePin.fromJson(
      jsonDecode(await File(arguments.last).readAsString())
          as Map<String, Object?>,
    );
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(await webRuntimeHashes(pin)),
    );
    return;
  }
  if (arguments.length != 1 || arguments.single.startsWith('-')) {
    stderr.writeln(
      'Usage: dart run mediapipe_core:web_runtime <output folder>',
    );
    stderr.writeln(
      '   or: dart run mediapipe_core:web_runtime --hashes <runtime.json>',
    );
    exit(64);
  }
  final output = Directory(arguments.single);
  var hosted = 0;
  for (final family in _families) {
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:$family/'),
    );
    if (library == null) continue;
    final pin = WebRuntimePin.fromJson(
      jsonDecode(
            await File.fromUri(
              library.resolve('../assets/runtime.json'),
            ).readAsString(),
          )
          as Map<String, Object?>,
    );
    final target = await hostWebRuntime(pin, output);
    stdout.writeln('${pin.package}@${pin.version} -> ${target.path}');
    hosted++;
  }
  if (hosted == 0) {
    stderr.writeln(
      'This app depends on no MediaPipe task family (${_families.join(', ')}).',
    );
    exit(1);
  }
}

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:mediapipe_core/native_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Bundles Google's MediaPipe audio library and this package's stream bridge.
/// Browsers run Google's JavaScript runtime through this package's plugin
/// instead.
Future<void> main(List<String> args) => build(args, (input, output) async {
  if (!input.config.buildCodeAssets) return;
  final code = input.config.code;
  await bundleFamilyRuntime(input, output, family: 'audio');
  // The stream bridge only copies Google's audio stream results inside its
  // callback; it does not link or modify MediaPipe.
  final windows = code.targetOS == OS.windows;
  await CBuilder.library(
    name: 'mediapipe_audio_stream',
    assetName: 'audio_stream_bridge.dylib',
    sources: ['native/audio_stream_bridge.c'],
    includes: ['native'],
    flags: windows ? ['/W4', '/WX'] : ['-Wall', '-Wextra', '-Werror'],
  ).run(input: input, output: output);
});

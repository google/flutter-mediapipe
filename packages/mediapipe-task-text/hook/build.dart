import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:mediapipe_core/native_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Bundles Google's MediaPipe text library and this package's stream bridge.
/// Browsers run Google's JavaScript runtime through this package's plugin
/// instead.
Future<void> main(List<String> args) => build(args, (input, output) async {
  if (!input.config.buildCodeAssets) return;
  final code = input.config.code;
  await bundleFamilyRuntime(input, output, family: 'text');
  // Only copies ephemeral generative callbacks; does not link/modify MediaPipe.
  final windows = code.targetOS == OS.windows;
  await CBuilder.library(
    name: 'mediapipe_text_stream',
    assetName: 'text_stream_bridge.dylib',
    sources: ['native/text_stream_bridge.c'],
    includes: ['native'],
    flags: windows ? ['/W4', '/WX'] : ['-Wall', '-Wextra', '-Werror'],
  ).run(input: input, output: output);
});

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:mediapipe_core/native_assets.dart';

/// Bundles Google's MediaPipe library with Decision Maker: its per-family
/// decision library. Browsers run Google's JavaScript runtime through this
/// package's plugin.
Future<void> main(List<String> args) => build(args, (input, output) async {
  if (!input.config.buildCodeAssets) return;
  await bundleFamilyRuntime(input, output, family: 'decision');
});

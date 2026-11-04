import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:mediapipe_core/native_assets.dart';

/// Bundles Google's per-family MediaPipe library with Universal Embedder and
/// Semantic Retriever for the build's target, as the vision, text and audio
/// hooks do; browsers run Google's JavaScript runtime through this package's
/// plugin instead.
Future<void> main(List<String> args) => build(args, (input, output) async {
  if (!input.config.buildCodeAssets) return;
  await bundleFamilyRuntime(input, output, family: 'retrieval');
});

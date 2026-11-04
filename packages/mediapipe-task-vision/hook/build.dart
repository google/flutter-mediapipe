import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:mediapipe_core/native_assets.dart';

import '../vision_tasks.dart';

/// Bundles Google's MediaPipe vision library, which every vision task binds
/// as `package:mediapipe_vision/mediapipe.dylib`.
void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final target = buildTarget(code);
    requireDynamicLinking(code);
    // TODO: Bundle the app's `models:` list here as data assets, retiring
    // `dart run mediapipe_core:bundle_models`. Waits on data assets reaching
    // Flutter stable. See packages/mediapipe-core/tool/MODEL_BUNDLING.md.
    final selection =
        input.userDefines['tasks'] ?? ['face_detector', 'face_landmarker'];
    if (selection is! List ||
        selection.isEmpty ||
        selection.any((task) => !visionTasks.contains(task))) {
      throw FormatException(
        'mediapipe_vision.tasks must be a nonempty list of '
        '${visionTasks.join(', ')}.',
      );
    }
    output.dependencies.add(input.packageRoot.resolve('vision_tasks.dart'));
    final tasks = selection.cast<String>().toSet();
    // Names the targets that have a library, with the fix for Intel slices.
    requireFamilyRuntime('vision', target);
    final validated = visionRuntimeTasks[target]!;
    final missing = tasks.difference(validated);
    if (missing.isNotEmpty) {
      throw UnsupportedError(
        'mediapipe_vision is not validated for ${missing.join(', ')} on '
        '$target. Validated: ${validated.join(', ')}.',
      );
    }
    await bundleFamilyRuntime(input, output, family: 'vision');
  });
}

import 'package:gallery_builder/models.dart';
import 'package:test/test.dart';

import '../../../packages/mediapipe-task-vision/vision_tasks.dart';

final targetTasks = galleryTargets(visionRuntimeTasks);

void main() {
  test('every task a target bundles has a pinned model', () {
    for (final MapEntry(key: target, value: tasks) in targetTasks.entries) {
      expect(models.keys, containsAll(tasks), reason: target);
    }
  });

  test('native targets bundle the vision tasks the vision hook accepts', () {
    for (final target in nativeTargets) {
      expect(
        targetTasks[target]!.difference(nonVisionTasks),
        visionRuntimeTasks[target],
        reason: target,
      );
    }
    // Google's Windows libraries run the stateful segmenter too slowly to
    // offer.
    for (final target in ['windows/x64', 'windows/arm64']) {
      expect(
        targetTasks[target],
        isNot(contains('interactive_segmenter')),
        reason: target,
      );
    }
    expect(targetTasks['macos/arm64'], hasLength(models.length));
  });

  test('the web build lists only tasks Google serves in browsers', () {
    expect(webTasks, isNot(contains('text_proofreader')));
    expect(webTasks, isNot(contains('text_summarizer')));
    expect(webHostTestTasks.difference(webTasks), isEmpty);
  });
}

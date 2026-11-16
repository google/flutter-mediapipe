import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/task_settings.dart';

void main() {
  // Google's guides take any whole number above 0 for these, and its web
  // demo's sliders run from 1 to 10.
  test('the hand, pose and result counts run from 1 to 10', () {
    for (final (task, key) in [
      ('hand_landmarker', 'numHands'),
      ('gesture_recognizer', 'numHands'),
      ('pose_landmarker', 'numPoses'),
      ('object_detector', 'maxResults'),
      ('image_classifier', 'maxResults'),
      ('audio_classifier', 'maxResults'),
      ('text_classifier', 'maxResults'),
      ('language_detector', 'maxResults'),
    ]) {
      final setting = taskSettings[task]!.whereType<CountSetting>().singleWhere(
        (setting) => setting.key == key,
      );
      expect((setting.min, setting.max), (1, 10), reason: '$task $key');
    }
  });
}

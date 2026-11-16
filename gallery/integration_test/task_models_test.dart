import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live/task_models.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'support/sdk_frames.dart';

/// As in sdk_detection_tasks_test.dart: `skip` runs CPU only, where the
/// simulator aborts in Google's Metal preprocessing.
const _gpu = String.fromEnvironment('SDK_GPU', defaultValue: 'optional');

/// Every Face Detector model the gallery's menu offers downloads from
/// Google, matches its pin and finds the portrait's face on each delegate
/// the page offers.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final model in taskModels['face_detector']!) {
    testWidgets('Face Detector runs ${model.name}', (tester) async {
      await tester.runAsync(() async {
        final platform = (await queryFaceDetectorCapabilities()).platform;
        final task = supportedTasks(platform, {'face_detector'}).single;
        final delegates = [
          for (final delegate in task.capabilities(platform).supportedDelegates)
            if (delegate == Delegate.cpu || _gpu != 'skip') delegate,
        ];
        expect(delegates, contains(Delegate.cpu));
        final bytes = await downloadModel(model);
        final frame = await loadSample('portrait.jpg');
        for (final delegate in delegates) {
          final detector = await FaceDetector.create(
            FaceDetectorOptions(modelBytes: bytes, delegate: delegate),
          );
          try {
            final result = await detector.detect(frame.image);
            expect(result.detections, hasLength(1), reason: '$delegate');
          } finally {
            await detector.dispose();
          }
        }
      });
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetector> createLiveDetector(
  void Function(ObjectDetectorResult result) onResult,
) async {
  final detector = await ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      runningMode: RunningMode.liveStream,
      maxResults: 5,
    ),
  );
  detector.results.listen(
    onResult,
    onError: (Object error) => print('Detection failed: $error'),
  );
  return detector;
}

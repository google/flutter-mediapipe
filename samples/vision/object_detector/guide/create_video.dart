import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetector> createVideoDetector() => ObjectDetector.create(
  ObjectDetectorOptions(
    model: VisionModels.objectDetector,
    runningMode: RunningMode.video,
    maxResults: 5,
  ),
);

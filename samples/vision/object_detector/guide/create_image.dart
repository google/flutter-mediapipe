import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetector> createImageDetector() => ObjectDetector.create(
  ObjectDetectorOptions(
    model: VisionModels.objectDetector,
    runningMode: RunningMode.image,
    maxResults: 5,
  ),
);

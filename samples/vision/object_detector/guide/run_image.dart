import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetectorResult> detectImage(
  ObjectDetector detector,
  VisionImage image,
) => detector.detect(image);

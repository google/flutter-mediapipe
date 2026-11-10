import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetectorResult> detectVideoFrame(
  ObjectDetector detector,
  VisionImage frame,
  Duration presentationTime, {
  int rotationDegrees = 0,
}) => detector.detectForVideo(
  frame,
  timestampMilliseconds: presentationTime.inMilliseconds,
  rotationDegrees: rotationDegrees,
);

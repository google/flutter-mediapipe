import 'package:mediapipe_vision/mediapipe_vision.dart';

final _clock = Stopwatch()..start();

void detectCameraFrame(
  ObjectDetector detector,
  VisionImage frame, {
  int rotationDegrees = 0,
}) {
  // The result arrives on detector.results.
  detector.detectAsync(
    frame,
    timestampMilliseconds: _clock.elapsedMilliseconds,
    rotationDegrees: rotationDegrees,
  );
}

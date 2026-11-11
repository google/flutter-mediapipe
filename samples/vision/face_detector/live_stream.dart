import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findFacesLive(Stream<Frame> frames) async {
  final detector = await FaceDetector.create(
    FaceDetectorOptions(
      model: VisionModels.faceDetector,
      runningMode: RunningMode.liveStream,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = detector.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final face in result.detections) {
      final box = face.boundingBox;
      final score = face.categories.first.score.toStringAsFixed(2);
      print('$ms ms: face at ${box.left},${box.top}, confidence $score');
    }
  });
  try {
    await for (final frame in frames) {
      detector.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await detector.dispose();
    await results.cancel();
    print('${detector.droppedFrames} frames dropped');
  }
}

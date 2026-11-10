import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findFacesInVideo(Stream<Frame> frames) async {
  final detector = await FaceDetector.create(
    FaceDetectorOptions(
      model: VisionModels.faceDetector,
      runningMode: RunningMode.video,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await detector.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final face in result.detections) {
        final box = face.boundingBox;
        final score = face.categories.first.score.toStringAsFixed(2);
        print('$ms ms: face at ${box.left},${box.top}, confidence $score');
      }
    }
  } finally {
    await detector.dispose();
  }
}

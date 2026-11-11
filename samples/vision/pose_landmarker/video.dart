import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findPosesInVideo(Stream<Frame> frames) async {
  final landmarker = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      model: VisionModels.poseLandmarker,
      runningMode: RunningMode.video,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await landmarker.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final pose in result.poseLandmarks) {
        final nose = pose.first;
        print('$ms ms: nose at ${nose.x}, ${nose.y}');
      }
    }
  } finally {
    await landmarker.dispose();
  }
}

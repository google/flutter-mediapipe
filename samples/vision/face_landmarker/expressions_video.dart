import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> readExpressionsInVideo(Stream<Frame> frames) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      runningMode: RunningMode.video,
      outputFaceBlendshapes: true,
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
      for (final shapes in result.faceBlendshapes) {
        final top = shapes.reduce((a, b) => a.score >= b.score ? a : b);
        print('$ms ms: ${top.categoryName} ${top.score.toStringAsFixed(2)}');
      }
    }
  } finally {
    await landmarker.dispose();
  }
}

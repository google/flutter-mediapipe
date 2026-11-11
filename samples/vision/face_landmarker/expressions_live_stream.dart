import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> readExpressionsLive(Stream<Frame> frames) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      runningMode: RunningMode.liveStream,
      outputFaceBlendshapes: true,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = landmarker.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final shapes in result.faceBlendshapes) {
      final top = shapes.reduce((a, b) => a.score >= b.score ? a : b);
      print('$ms ms: ${top.categoryName} ${top.score.toStringAsFixed(2)}');
    }
  });
  try {
    await for (final frame in frames) {
      landmarker.detectAsync(
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
    await landmarker.dispose();
    await results.cancel();
    print('${landmarker.droppedFrames} frames dropped');
  }
}

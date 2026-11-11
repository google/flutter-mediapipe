import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findPosesLive(Stream<Frame> frames) async {
  final landmarker = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      model: VisionModels.poseLandmarker,
      runningMode: RunningMode.liveStream,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = landmarker.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final pose in result.poseLandmarks) {
      final nose = pose.first;
      print('$ms ms: nose at ${nose.x}, ${nose.y}');
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

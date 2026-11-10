import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findHandsLive(Stream<Frame> frames) async {
  final landmarker = await HandLandmarker.create(
    HandLandmarkerOptions(
      model: VisionModels.handLandmarker,
      runningMode: RunningMode.liveStream,
      numHands: 2,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = landmarker.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (var i = 0; i < result.handLandmarks.length; i++) {
      final side = result.handedness[i].first.categoryName;
      final wrist = result.handLandmarks[i].first;
      print('$ms ms: $side hand, wrist at ${wrist.x}, ${wrist.y}');
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

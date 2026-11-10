import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findHandsInVideo(Stream<Frame> frames) async {
  final landmarker = await HandLandmarker.create(
    HandLandmarkerOptions(
      model: VisionModels.handLandmarker,
      runningMode: RunningMode.video,
      numHands: 2,
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
      for (var i = 0; i < result.handLandmarks.length; i++) {
        final side = result.handedness[i].first.categoryName;
        final wrist = result.handLandmarks[i].first;
        print('$ms ms: $side hand, wrist at ${wrist.x}, ${wrist.y}');
      }
    }
  } finally {
    await landmarker.dispose();
  }
}

import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> trackPersonLive(Stream<Frame> frames) async {
  final landmarker = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      model: VisionModels.holisticLandmarker,
      runningMode: RunningMode.liveStream,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = landmarker.results.listen((result) {
    final ms = result.timestampMilliseconds;
    print(
      '$ms ms: ${result.faceLandmarks.length} face, '
      '${result.poseLandmarks.length} pose, '
      '${result.leftHandLandmarks.length} left hand and '
      '${result.rightHandLandmarks.length} right hand landmarks',
    );
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

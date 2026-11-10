import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> trackPersonInVideo(Stream<Frame> frames) async {
  final landmarker = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      model: VisionModels.holisticLandmarker,
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
      print(
        '$ms ms: ${result.faceLandmarks.length} face, '
        '${result.poseLandmarks.length} pose, '
        '${result.leftHandLandmarks.length} left hand and '
        '${result.rightHandLandmarks.length} right hand landmarks',
      );
    }
  } finally {
    await landmarker.dispose();
  }
}

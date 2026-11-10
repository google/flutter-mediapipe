import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> countFacesInVideo(Stream<Frame> decodedFrames) async {
  final task = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      runningMode: RunningMode.video,
    ),
  );
  try {
    await for (final frame in decodedFrames) {
      final result = await task.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      print('${frame.milliseconds} ms: ${result.faceLandmarks.length} faces');
    }
  } finally {
    await task.dispose();
  }
}

import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<int> countFaces(Uint8List rgba, int width, int height) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(model: VisionModels.faceLandmarker),
  );
  try {
    final result = await landmarker.detect(
      VisionImage.fromPixels(
        pixels: rgba,
        width: width,
        height: height,
        format: VisionPixelFormat.rgba,
      ),
    );
    return result.faceLandmarks.length;
  } finally {
    await landmarker.dispose();
  }
}

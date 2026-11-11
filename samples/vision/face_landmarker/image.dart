import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> detectFaces(Uint8List rgba, int width, int height) async {
  final task = await FaceLandmarker.create(
    FaceLandmarkerOptions(model: VisionModels.faceLandmarker, numFaces: 1),
  );
  try {
    final result = await task.detect(
      VisionImage.fromPixels(
        pixels: rgba,
        width: width,
        height: height,
        format: VisionPixelFormat.rgba,
      ),
    );
    for (final face in result.faceLandmarks) {
      print('${face.length} landmarks'); // 478 with the official bundle
      print('First landmark: ${face.first.x}, ${face.first.y}');
    }
  } finally {
    await task.dispose();
  }
}

import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> findFacesInRgb(Uint8List rgb, int width, int height) async {
  final detector = await FaceDetector.create(
    FaceDetectorOptions(model: VisionModels.faceDetector),
  );
  try {
    final result = await detector.detect(
      VisionImage.fromPixels(
        pixels: rgb,
        width: width,
        height: height,
        format: VisionPixelFormat.rgb,
      ),
    );
    for (final face in result.detections) {
      final box = face.boundingBox;
      print('Face at ${box.left},${box.top}, ${box.width}x${box.height}');
    }
  } finally {
    await detector.dispose();
  }
}

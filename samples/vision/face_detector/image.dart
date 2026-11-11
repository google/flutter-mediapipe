import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> findFaces(VisionImage image) async {
  final detector = await FaceDetector.create(
    FaceDetectorOptions(model: VisionModels.faceDetector),
  );
  try {
    final result = await detector.detect(image);
    for (final face in result.detections) {
      final box = face.boundingBox;
      print('Face at ${box.left},${box.top}, ${box.width}x${box.height} px');
      print('Confidence ${face.categories.first.score.toStringAsFixed(2)}');
    }
  } finally {
    await detector.dispose();
  }
}

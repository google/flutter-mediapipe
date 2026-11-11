import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> detectObjects(VisionImage image) async {
  final detector = await ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      maxResults: 5,
      scoreThreshold: 0.4,
    ),
  );
  try {
    final result = await detector.detect(image);
    for (final detection in result.detections) {
      final label = detection.categories.first;
      final box = detection.boundingBox;
      print('${label.categoryName} at ${box.left},${box.top}');
    }
  } finally {
    await detector.dispose();
  }
}

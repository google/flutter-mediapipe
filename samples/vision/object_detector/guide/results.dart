import 'package:mediapipe_vision/mediapipe_vision.dart';

void printDetections(ObjectDetectorResult result) {
  for (final (index, detection) in result.detections.indexed) {
    final box = detection.boundingBox;
    print('Detection #$index:');
    print(
      '  Box: (left: ${box.left}, top: ${box.top}, '
      'right: ${box.right}, bottom: ${box.bottom})',
    );
    for (final category in detection.categories) {
      print(
        '  Category: ${category.categoryName} '
        '(score ${category.score.toStringAsFixed(2)})',
      );
    }
  }
}

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> classifyPhoto(VisionImage image) async {
  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(model: VisionModels.imageClassifier, maxResults: 3),
  );
  try {
    final result = await classifier.classify(image);
    for (final category in result.classifications.first.categories) {
      print('${category.categoryName}: ${category.score.toStringAsFixed(2)}');
    }
  } finally {
    await classifier.dispose();
  }
}

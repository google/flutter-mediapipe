import 'package:mediapipe_text/mediapipe_text.dart';

Future<String?> topCategory(String text) async {
  final classifier = await TextClassifier.create(
    TextClassifierOptions(model: TextModels.bertClassifier),
  );
  try {
    final result = await classifier.classify(text);
    return result.classifications.first.categories.first.categoryName;
  } finally {
    await classifier.dispose();
  }
}

import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> classify() async {
  final classifier = await TextClassifier.create(
    TextClassifierOptions(model: TextModels.bertClassifier),
  );
  try {
    final result = await classifier.classify('Hello, world!');
    final top = result.classifications.first.categories.first;
    print('${top.categoryName}: ${top.score}');
  } finally {
    await classifier.dispose();
  }
}

import 'dart:io';

import 'package:mediapipe_text/mediapipe_text.dart';

/// Classifies the sentiment of a sentence from the command line with Google's
/// pinned BERT classifier: `dart run example/example.dart "What a great film"`.
///
/// A Dart program has no app bundle, so this downloads the model once into
/// `.dart_tool/mediapipe_models/`, checks its SHA-256 and passes its path. A
/// Flutter app bundles the model instead, by listing `bert_classifier` under
/// `hooks.user_defines.mediapipe_text.models` and running
/// `dart run mediapipe_core:bundle_models`, then passes
/// `model: TextModels.bertClassifier`.
Future<void> main(List<String> arguments) async {
  final store = ModelStore(
    cacheDirectory: Directory('.dart_tool/mediapipe_models').absolute.path,
  );
  final model = await store.get(TextModels.bertClassifier);
  final classifier = await TextClassifier.create(
    TextClassifierOptions(modelPath: model.path, maxResults: 2),
  );
  try {
    final result = await classifier.classify(arguments.join(' '));
    for (final category in result.classifications.first.categories) {
      print('${category.categoryName} ${category.score.toStringAsFixed(4)}');
    }
  } finally {
    await classifier.dispose();
  }
}

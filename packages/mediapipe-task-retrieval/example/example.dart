import 'dart:io';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

/// Finds the closest of three sentences to a query from the command line with
/// Google's pinned EmbeddingGemma 2 text and vision model:
/// `dart run example/example.dart "A puppy playing fetch."`.
///
/// A Dart program has no app bundle, so this downloads the model once into
/// `.dart_tool/mediapipe_models/`, checks its SHA-256 and passes its path. A
/// Flutter app bundles the model instead, by listing
/// `embedding_gemma_2_text_vision` under
/// `hooks.user_defines.mediapipe_retrieval.models` and running
/// `dart run mediapipe_core:bundle_models`, then passes
/// `model: RetrievalModels.embeddingGemma2TextVision`.
Future<void> main(List<String> arguments) async {
  final store = ModelStore(
    cacheDirectory: Directory('.dart_tool/mediapipe_models').absolute.path,
  );
  final model = await store.get(RetrievalModels.embeddingGemma2TextVision);
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(modelPath: model.path),
  );
  final retriever = await SemanticRetriever.create(
    SemanticRetrieverOptions(embedder: embedder),
  );
  try {
    await retriever.insertDocument(
      'dog',
      'A dog chases a ball across the park on a sunny afternoon.',
    );
    await retriever.insertDocument(
      'recipe',
      'Whisk the eggs with sugar, then fold in the flour to make the batter.',
    );
    await retriever.insertDocument(
      'train',
      'The night train to Lisbon leaves the station at ten.',
    );
    final result = await retriever.retrieve(arguments.join(' '), limit: 1);
    for (final record in result.records) {
      print('${record.id} ${record.score.toStringAsFixed(4)}');
    }
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}

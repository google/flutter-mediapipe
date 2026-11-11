import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<void> search() async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2TextVision,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  final SemanticRetriever retriever;
  try {
    retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder),
    );
  } catch (_) {
    await embedder.dispose();
    rethrow;
  }
  try {
    await retriever.insertDocument(
      'dog',
      'A dog chases a ball across the park on a sunny afternoon.',
      metadata: {'topic': 'animals'},
    );
    await retriever.insertDocument(
      'recipe',
      'Whisk the eggs with sugar, then fold in the flour to make the batter.',
      metadata: {'topic': 'cooking'},
    );
    final result = await retriever.retrieve('A puppy playing fetch.', limit: 1);
    print('${result.records.first.id}: ${result.records.first.score}');

    final a = await embedder.embedText('A dog chases a ball.');
    final b = await embedder.embedText('A puppy plays fetch.');
    print(
      UniversalEmbedder.cosineSimilarity(
        a.embeddings.first,
        b.embeddings.first,
      ),
    );
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}

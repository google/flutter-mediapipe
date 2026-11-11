import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<void> todoList() async {
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
    final notes = {
      'milk': ('Buy milk and bread.', 'shopping'),
      'eggs': ('Buy a dozen eggs.', 'shopping'),
      'dentist': ('See the dentist on Tuesday at three.', 'calendar'),
      'plumber': ('Call the plumber about the leaking sink.', 'calendar'),
    };
    for (final MapEntry(key: id, value: (text, list)) in notes.entries) {
      await retriever.insertDocument(id, text, metadata: {'list': list});
    }
    final result = await retriever.retrieve(
      'What do I need from the store?',
      limit: 3,
      minSimilarity: 0.6,
      metadataFilter: {'list': 'shopping'},
    );
    for (final record in result.records) {
      print('${record.id}: ${record.score.toStringAsFixed(2)}');
    }
    await retriever.delete('plumber');
    await retriever.deleteWithMetadataFilter({'list': 'shopping'});
    print(await retriever.getAllRecordIds());
    await retriever.deleteAll();
    print(await retriever.getAllRecordIds());
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}

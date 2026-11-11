import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

/// Adds [note] to the index kept at [databasePath] and prints the id of
/// every note stored there, from this run and earlier ones.
Future<void> keepNote(String databasePath, String id, String note) async {
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(model: RetrievalModels.embeddingGemma2TextVision),
  );
  final SemanticRetriever retriever;
  try {
    retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder, databasePath: databasePath),
    );
  } catch (_) {
    await embedder.dispose();
    rethrow;
  }
  try {
    await retriever.insertDocument(id, note);
    print(await retriever.getAllRecordIds());
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}

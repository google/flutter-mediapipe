import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

/// Prints the indexed [photos] nearest to [query], best first.
Future<void> similarPhotos(
  Map<String, Uint8List> photos,
  Uint8List query,
) async {
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
    for (final MapEntry(key: id, value: bytes) in photos.entries) {
      await retriever.insertImage(id, imageBytes: bytes);
    }
    final result = await retriever.retrieveContent([
      ImagePart(imageBytes: query),
    ], limit: 3);
    for (final record in result.records) {
      print('${record.id}: ${record.score}');
    }
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}

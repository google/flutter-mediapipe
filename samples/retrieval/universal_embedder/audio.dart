import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<double> soundMatch(Float32List samples, String description) async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  try {
    final sound = await embedder.embedAudio(samples);
    final text = await embedder.embedText(description);
    return UniversalEmbedder.cosineSimilarity(
      sound.embeddings.first,
      text.embeddings.first,
    );
  } finally {
    await embedder.dispose();
  }
}

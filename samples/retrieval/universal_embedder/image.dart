import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<double> captionMatch(Uint8List photo, String caption) async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2TextVision,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  try {
    final image = await embedder.embedImage(photo);
    final text = await embedder.embedText(caption);
    return UniversalEmbedder.cosineSimilarity(
      image.embeddings.first,
      text.embeddings.first,
    );
  } finally {
    await embedder.dispose();
  }
}

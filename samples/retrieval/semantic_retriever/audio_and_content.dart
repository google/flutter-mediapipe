import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

/// Indexes a sound, a voice memo with its title and a photo with its
/// caption, then finds the record nearest a text and a spoken query.
Future<void> searchMedia({
  required Float32List birdsong,
  required Float32List memo,
  required Uint8List photo,
  required Float32List spokenQuery,
}) async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2,
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
    await retriever.insertAudio('birdsong', audioData: birdsong);
    await retriever.insertContent('memo', [
      TextPart('Voice memo: plans for the weekend.'),
      AudioPart(audioData: memo),
    ]);
    await retriever.insertContent('cat', [
      ImagePart(imageBytes: photo),
      TextPart('Our cat asleep on the sofa.'),
    ]);
    final byText = await retriever.retrieve('A sleeping kitten.', limit: 1);
    print('A sleeping kitten: ${byText.records.first.id}');
    final bySound = await retriever.retrieveContent([
      AudioPart(audioData: spokenQuery),
    ], limit: 1);
    print('The spoken query: ${bySound.records.first.id}');
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}

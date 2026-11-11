import 'package:mediapipe_text/mediapipe_text.dart';

Future<double> similarity(String a, String b) async {
  final task = await TextEmbedder.create(
    TextEmbedderOptions(model: TextModels.embeddingGemma),
  );
  try {
    final context = TextFormatContext(
      taskType: EmbeddingType.semanticSimilarity,
    );
    final first = await task.embed(a, formatContext: context);
    final second = await task.embed(b, formatContext: context);
    return TextEmbedder.cosineSimilarity(
      first.embeddings.single,
      second.embeddings.single,
    );
  } finally {
    await task.dispose();
  }
}

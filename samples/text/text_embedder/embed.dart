import 'package:mediapipe_text/mediapipe_text.dart';

Future<double> compareSentences(String first, String second) async {
  final embedder = await TextEmbedder.create(
    TextEmbedderOptions(model: TextModels.universalSentenceEncoder),
  );
  try {
    final a = await embedder.embed(first);
    final b = await embedder.embed(second);
    return TextEmbedder.cosineSimilarity(
      a.embeddings.first,
      b.embeddings.first,
    );
  } finally {
    await embedder.dispose();
  }
}

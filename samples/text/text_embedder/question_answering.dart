import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> bestAnswer(String question, Map<String, String> answers) async {
  final task = await TextEmbedder.create(
    TextEmbedderOptions(model: TextModels.embeddingGemma),
  );
  try {
    final query = await task.embed(
      question,
      formatContext: TextFormatContext(
        taskType: EmbeddingType.questionAnswering,
      ),
    );
    for (final MapEntry(key: title, value: answer) in answers.entries) {
      final document = await task.embed(
        answer,
        formatContext: TextFormatContext(
          taskType: EmbeddingType.questionAnswering,
          role: TextRole.document,
          title: title,
        ),
      );
      final score = TextEmbedder.cosineSimilarity(
        query.embeddings.single,
        document.embeddings.single,
      );
      print('$title: ${score.toStringAsFixed(2)}');
    }
  } finally {
    await task.dispose();
  }
}

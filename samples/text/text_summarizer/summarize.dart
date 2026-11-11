import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> summarize(String article) async {
  final task = await TextSummarizer.create(
    TextSummarizerOptions(
      model: TextModels.summarizer,
      mode: TextSummarizerMode.tldr,
    ),
  );
  try {
    print((await task.summarize(article)).summary);
    await for (final update in task.summarizeStream(article)) {
      if (update.chunk != null) print(update.chunk);
    }
  } finally {
    await task.dispose();
  }
}

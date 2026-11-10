import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> listKeyPoints(String article) async {
  final task = await TextSummarizer.create(
    TextSummarizerOptions(
      model: TextModels.summarizer,
      mode: TextSummarizerMode.keypoints,
    ),
  );
  try {
    final summary = (await task.summarize(article)).summary ?? '';
    for (final line in summary.split('\n')) {
      if (line.startsWith('* ')) print(line.substring(2));
    }
  } finally {
    await task.dispose();
  }
}

import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> reportTextSupport() async {
  final queries = <String, Future<TaskCapabilities> Function()>{
    'Text Classifier': queryTextClassifierCapabilities,
    'Language Detector': queryLanguageDetectorCapabilities,
    'Text Embedder': queryTextEmbedderCapabilities,
    'EmbeddingGemma': () =>
        queryTextEmbedderCapabilities(TextModels.embeddingGemma),
    'Proofreader': queryTextProofreaderCapabilities,
    'Summarizer': queryTextSummarizerCapabilities,
  };
  for (final MapEntry(key: task, value: query) in queries.entries) {
    final support = await query();
    final delegates = support.supportedDelegates.map((d) => d.name);
    print('$task: ${delegates.join(', ')}');
    for (final MapEntry(key: delegate, value: reason)
        in support.unavailableReasons.entries) {
      print('  no ${delegate.name}: $reason');
    }
  }
}

import 'package:mediapipe_text/mediapipe_text.dart';

export 'universal_text_classifier.dart'
    if (dart.library.html) 'text_classifier_web.dart'
    if (dart.library.io) 'text_classifier_io.dart';

/// Channel to analyze text via MediaPipe's text classification task.
abstract class BaseTextClassifier {
  /// Generative constructor.
  BaseTextClassifier({required this.options});

  /// Configuration wobject for tasks completed by this classifier.
  final TextClassifierOptions options;

  /// Sends a `String` value to MediaPipe for classification. Uses an Isolate
  /// on mobile and desktop, and a web worker on web, to add concurrency and avoid
  /// blocking the UI thread while this task completes.
  ///
  /// See also:
  ///  * [classify_sync] for a synchronous alternative
  Future<TextClassifierResult> classify(String text);

  /// Sends a `String` value to MediaPipe for classification. Blocks the main
  /// event loop for the duration of the task, so use this with caution.
  ///
  /// See also:
  ///  * [classify] for a concurrent alternative
  TextClassifierResult classifySync(String text);
}

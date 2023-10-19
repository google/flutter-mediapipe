import 'package:mediapipe_text/mediapipe_text.dart';

export 'universal_text_classifier.dart'
    if (dart.library.html) 'text_classifier_web.dart'
    if (dart.library.io) 'text_classifier_io.dart';

/// Channel to analyze text via MediaPipe's text classification task.
abstract class BaseTextClassifier {
  BaseTextClassifier({required this.options});

  /// Configuration object for tasks completed by this classifier.
  final TextClassifierOptions options;

  /// Sends a `String` value to MediaPipe for classification.
  TextClassifierResult classify(String text);
}

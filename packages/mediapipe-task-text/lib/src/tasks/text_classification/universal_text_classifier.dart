import 'package:mediapipe_text/mediapipe_text.dart';

/// Channel to classify text via MediaPipe's "classifyText" Task.
class TextClassifier extends BaseTextClassifier {
  TextClassifier({required super.options}) {
    throw Exception('Must use the web or FFI implementations');
  }

  /// Sends a `String` value to MediaPipe for classification.
  @override
  TextClassifierResult classify(String text) {
    throw Exception('Must use the web or FFI implementations');
  }
}

import 'package:mediapipe_text/mediapipe_text.dart';

/// Channel to classify text via MediaPipe's "classifyText" Task.
class TextClassifier extends BaseTextClassifier {
  /// Generative constructor.
  TextClassifier({required super.options}) {
    throw Exception('Must use the web or FFI implementations');
  }

  /// Sends a `String` value to MediaPipe for classification. Uses an Isolate
  /// on mobile and desktop, and a web worker on web, to add concurrency and avoid
  /// blocking the UI thread while this task completes.
  @override
  Future<TextClassifierResult> classify(String text) async {
    throw Exception('Must use the web or FFI implementations');
  }
}

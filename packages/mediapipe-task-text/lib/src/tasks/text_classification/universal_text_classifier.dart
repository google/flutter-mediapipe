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
  ///
  /// See also:
  ///  * [classify_sync] for a synchronous alternative
  @override
  Future<TextClassifierResult> classify(String text) async {
    throw Exception('Must use the web or FFI implementations');
  }

  /// Sends a `String` value to MediaPipe for classification. Blocks the main
  /// event loop for the duration of the task, so use this with caution.
  ///
  /// See also:
  ///  * [classify] for a concurrent alternative
  @override
  TextClassifierResult classifySync(String text) {
    throw Exception('Must use the web or FFI implementations');
  }
}

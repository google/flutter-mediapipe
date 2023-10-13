import 'package:mediapipe_text/mediapipe_text.dart';

export 'universal_text_classifier.dart'
    if (dart.library.html) 'web_text_classifier.dart'
    if (dart.library.io) 'ffi_text_classifier.dart';

/// Channel to analyze text via MediaPipe's text classification task.
abstract class BaseTextClassifier {
  BaseTextClassifier({required this.options});

  /// Configuration object passed into C or JavaScript to influence how
  /// MediaPipe completes the requested operation.
  final TextClassifierOptions options;

  /// Location for where to find the means to communicate with the MediaPipe SDK.
  ///
  /// For mobile and desktop targets, this should be the location on the local
  /// filesystem of the C wrappers.
  ///
  /// For web builds, this should be the namespace off the global `window`
  /// object where the JavaScript wrapper can be found.
  // final String sdkPath;

  /// Sends a `String` value to MediaPipe for classification.
  TextClassifierResult classify(String text);
}

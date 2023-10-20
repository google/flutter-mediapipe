import 'dart:ui';
import 'package:mediapipe_vision/mediapipe_vision.dart';

export 'universal_image_classifier.dart'
    if (dart.library.html) 'image_classifier_web.dart'
    if (dart.library.io) 'image_classifier_io.dart';

/// Channel to analyze images via MediaPipe's vision classification task.
abstract class BaseImageClassifier {
  /// Generative constructor.
  BaseImageClassifier({required this.options});

  /// Configuration object for tasks completed by this classifier.
  final ImageClassifierOptions options;

  /// Sends a `String` value to MediaPipe for classification.
  Future<ImageClassifierResult> classify(Image image);
}

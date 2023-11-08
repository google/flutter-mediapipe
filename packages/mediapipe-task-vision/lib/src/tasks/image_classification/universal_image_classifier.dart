import 'dart:ui';
import 'package:mediapipe_vision/mediapipe_vision.dart';

/// Channel to classify an image via MediaPipe's "classifyImage" task.
class ImageClassifier extends BaseImageClassifier {
  /// Generative constructor.
  ImageClassifier({required super.options}) {
    throw Exception('Must use the web or FFI implementations');
  }

  /// Sends an `Image` to MediaPipe for classification.
  @override
  Future<ImageClassifierResult> classify(Image image) {
    throw Exception('Must use the web or FFI implementations');
  }
}

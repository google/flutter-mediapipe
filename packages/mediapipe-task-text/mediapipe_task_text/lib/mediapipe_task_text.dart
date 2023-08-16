import 'package:mediapipe_task_text_platform_interface/mediapipe_task_text_platform_interface.dart';
export 'package:mediapipe_task_text_platform_interface/mediapipe_task_text_platform_interface.dart'
    show Category, ClassificationResult, Classifications, TextClassifierResult;

class MediaPipeTaskText {
  MediaPipeTaskText(this.modelPath);

  String modelPath;

  Future<void> initClassifier() =>
      MediaPipeTaskTextPlatform.instance.initClassifier(modelPath);

  Future<TextClassifierResult?> classify(String value) =>
      MediaPipeTaskTextPlatform.instance.classify(value);
}

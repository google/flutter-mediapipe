import 'package:mediapipe_task_text_platform_interface/mediapipe_task_text_platform_interface.dart';

class MediaPipeTaskText {
  MediaPipeTaskText(this.modelPath);

  String modelPath;

  Future<void> initClassifier() {
    return MediaPipeTaskTextPlatform.instance.initClassifier(modelPath);
  }

  Future<ClassificationResult?> classify(String value) =>
      MediaPipeTaskTextPlatform.instance.classify(value);
}

import 'package:mediapipe_task_text_platform_interface/mediapipe_task_text_platform_interface.dart';

class MediapipeTaskText {
  MediapipeTaskText(this.modelPath);

  String modelPath;

  Future<void> initClassifier() {
    return MediapipeTaskTextPlatform.instance.initClassifier(modelPath);
  }

  Future<ClassificationResult?> classify(String value) =>
      MediapipeTaskTextPlatform.instance.classify(value);
}

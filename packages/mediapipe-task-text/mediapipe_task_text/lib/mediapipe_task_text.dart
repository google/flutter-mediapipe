
import 'mediapipe_task_text_platform_interface.dart';

class MediapipeTaskText {
  Future<String?> getPlatformVersion() {
    return MediapipeTaskTextPlatform.instance.getPlatformVersion();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mediapipe_task_text_platform_interface.dart';

/// An implementation of [MediapipeTaskTextPlatform] that uses method channels.
class MethodChannelMediaPipeTaskText extends MediaPipeTaskTextPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('mediapipe_task_text');
}

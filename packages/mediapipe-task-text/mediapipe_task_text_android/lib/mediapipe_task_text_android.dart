library mediapipe_task_text_android;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_task_text_platform_interface/mediapipe_task_text_platform_interface.dart';

class AndroidMediapipeTaskTextPlatform extends MediaPipeTaskTextPlatform {
  AndroidMediapipeTaskTextPlatform();

  static void registerWith() {
    MediaPipeTaskTextPlatform.instance = AndroidMediapipeTaskTextPlatform();
  }

  @visibleForTesting
  final methodChannel = const MethodChannel('mediapipe_task_text');

  @override
  Future<void> initClassifier(String modelPath) async {
    await methodChannel.invokeMethod<String>('initClassifier', <String, String>{
      'modelPath': modelPath,
    });
  }

  @override
  Future<TextClassifierResult?> classify(String value) async {
    final serializedTextClassifierResult =
        await methodChannel.invokeMethod<String>('classify', <String, String>{
      'text': value,
    });
    if (serializedTextClassifierResult != null) {
      return TextClassifierResult.decode(serializedTextClassifierResult);
    }
    return null;
  }
}

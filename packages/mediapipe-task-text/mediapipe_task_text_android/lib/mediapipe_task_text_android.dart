library mediapipe_task_text_android;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_task_text_platform_interface/mediapipe_task_text_platform_interface.dart';

class AndroidMediaPipeTaskTextPlatform extends MediaPipeTaskTextPlatform {
  AndroidMediaPipeTaskTextPlatform({required super.token});

  @visibleForTesting
  final methodChannel = const MethodChannel('mediapipe_task_text');

  @override
  Future<void> init(String modelPath) async {
    await methodChannel.invokeMethod<String>('initClassifier', <String, String>{
      'modelPath': modelPath,
    });
  }

  @override
  Future<String?> getPlatformVersion() async =>
      methodChannel.invokeMethod<String>('getPlatformVersion');

  @override
  Future<String?> classify(String text) async =>
      methodChannel.invokeMethod<String>('classify', <String, String>{
        'text': text,
      });
}

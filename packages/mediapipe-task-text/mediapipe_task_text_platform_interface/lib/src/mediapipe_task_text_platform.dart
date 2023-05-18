import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class MediaPipeTaskTextPlatform extends PlatformInterface {
  MediaPipeTaskTextPlatform({required super.token});

  Future<void> init(String modelPath);
  Future<String?> getPlatformVersion();
  Future<String?> classify(String text);
}

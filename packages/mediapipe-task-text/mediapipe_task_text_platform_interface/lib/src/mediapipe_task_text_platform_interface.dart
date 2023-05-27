import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'classification_result.dart';
import 'mediapipe_task_text_method_channel.dart';

abstract class MediapipeTaskTextPlatform extends PlatformInterface {
  /// Constructs a MediapipeTaskTextPlatform.
  MediapipeTaskTextPlatform() : super(token: _token);

  static final Object _token = Object();

  static MediapipeTaskTextPlatform _instance = MethodChannelMediapipeTaskText();

  /// The default instance of [MediapipeTaskTextPlatform] to use.
  ///
  /// Defaults to [MethodChannelMediapipeTaskText].
  static MediapipeTaskTextPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MediapipeTaskTextPlatform] when
  /// they register themselves.
  static set instance(MediapipeTaskTextPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initClassifier(String modelPath) {
    throw UnimplementedError("WTF why y'all not implement initClassifier");
  }

  Future<ClassificationResult?> classify(String value) {
    throw UnimplementedError("WTF why y'all not implement classify");
  }
}

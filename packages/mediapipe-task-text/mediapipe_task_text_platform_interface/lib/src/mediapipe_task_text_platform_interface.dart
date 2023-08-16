import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'classification.g.dart';
import 'mediapipe_task_text_method_channel.dart';

abstract class MediaPipeTaskTextPlatform extends PlatformInterface {
  /// Constructs a MediaPipeTaskTextPlatform.
  MediaPipeTaskTextPlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaPipeTaskTextPlatform _instance = MethodChannelMediaPipeTaskText();

  /// The default instance of [MediaPipeTaskTextPlatform] to use.
  ///
  /// Defaults to [MethodChannelMediapipeTaskText].
  static MediaPipeTaskTextPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MediaPipeTaskTextPlatform] when
  /// they register themselves.
  static set instance(MediaPipeTaskTextPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initClassifier(String modelPath) {
    throw UnimplementedError('$this should implement initClassifier(String)');
  }

  Future<TextClassifierResult?> classify(String value) {
    throw UnimplementedError('$this should implement classify(String)');
  }
}

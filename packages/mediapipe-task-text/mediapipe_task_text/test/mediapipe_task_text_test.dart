import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_task_text/mediapipe_task_text.dart';
import 'package:mediapipe_task_text_platform_interface/mediapipe_task_text_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaPipeTaskTextPlatform
    with MockPlatformInterfaceMixin
    implements MediaPipeTaskTextPlatform {
  @override
  Future<ClassificationResult?> classify(String value) {
    // TODO: implement classify
    throw UnimplementedError();
  }

  @override
  Future<void> initClassifier(String modelPath) {
    // TODO: implement initClassifier
    throw UnimplementedError();
  }
}

void main() {
  final MediaPipeTaskTextPlatform initialPlatform =
      MediaPipeTaskTextPlatform.instance;

  test('$MethodChannelMediaPipeTaskText is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMediaPipeTaskText>());
  });
}

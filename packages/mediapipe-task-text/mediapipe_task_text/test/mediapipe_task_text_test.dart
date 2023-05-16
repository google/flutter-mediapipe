import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_task_text/mediapipe_task_text.dart';
import 'package:mediapipe_task_text/mediapipe_task_text_platform_interface.dart';
import 'package:mediapipe_task_text/mediapipe_task_text_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediapipeTaskTextPlatform
    with MockPlatformInterfaceMixin
    implements MediapipeTaskTextPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MediapipeTaskTextPlatform initialPlatform = MediapipeTaskTextPlatform.instance;

  test('$MethodChannelMediapipeTaskText is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMediapipeTaskText>());
  });

  test('getPlatformVersion', () async {
    MediapipeTaskText mediapipeTaskTextPlugin = MediapipeTaskText();
    MockMediapipeTaskTextPlatform fakePlatform = MockMediapipeTaskTextPlatform();
    MediapipeTaskTextPlatform.instance = fakePlatform;

    expect(await mediapipeTaskTextPlugin.getPlatformVersion(), '42');
  });
}

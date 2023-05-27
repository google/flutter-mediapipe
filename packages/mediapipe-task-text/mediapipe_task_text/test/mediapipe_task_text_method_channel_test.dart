import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_task_text_platform_interface/mediapipe_task_text_platform_interface.dart';

// TODO: Move to platform_interface

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMediapipeTaskText platform = MethodChannelMediapipeTaskText();
  const MethodChannel channel = MethodChannel('mediapipe_task_text');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    // expect(await platform.getPlatformVersion(), '42');
  });
}

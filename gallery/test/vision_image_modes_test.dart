import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live_page.dart';

import 'support/scripted_camera.dart';

void main() {
  const platform = TaskPlatform(
    operatingSystem: 'macos',
    architecture: 'arm64',
    version: '15.0',
  );
  const runtimeIds = {
    'face_detector',
    'face_landmarker',
    'gesture_recognizer',
    'hand_landmarker',
    'holistic_landmarker',
    'image_classifier',
    'image_segmenter',
    'object_detector',
    'pose_landmarker',
  };
  final liveTasks = supportedTasks(
    platform,
    runtimeIds,
  ).where((task) => task.live).toList();

  test('every camera vision task has an image-capable gallery page', () {
    expect(liveTasks.map((task) => task.runtimeId).toSet(), runtimeIds);
  });

  for (final task in liveTasks) {
    testWidgets('${task.title} offers camera and still image modes', (
      tester,
    ) async {
      final previous = CameraPlatform.instance;
      CameraPlatform.instance = ScriptedCamera(cameras: const []);
      addTearDown(() => CameraPlatform.instance = previous);

      await tester.pumpWidget(
        MaterialApp(
          home: LivePage(
            task: task,
            platform: platform,
            initialStillImage: true,
          ),
        ),
      );
      await tester.pump();

      final id = task.runtimeId.replaceAll('_', '-');
      expect(find.byKey(ValueKey('$id-mode')), findsOneWidget);
      expect(find.text('Choose image'), findsOneWidget);
      expect(find.text('Choose an image to analyze.'), findsOneWidget);

      if (kIsWeb) {
        // Browser widget tests have no webcam permission or media stream.
        expect(find.text('Camera'), findsOneWidget);
        return;
      }
      await tester.tap(find.byKey(ValueKey('$id-mode-camera')));
      await tester.pumpAndSettle();
      expect(find.text('Choose image'), findsNothing);

      await tester.tap(find.byKey(ValueKey('$id-mode-image')));
      await tester.pumpAndSettle();
      expect(find.text('Choose image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

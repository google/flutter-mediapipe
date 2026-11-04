import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live_page.dart';

import 'support/scripted_camera.dart';

void main() {
  testWidgets('Face Landmarker offers camera and still image modes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final previous = CameraPlatform.instance;
    CameraPlatform.instance = ScriptedCamera(cameras: const []);
    addTearDown(() => CameraPlatform.instance = previous);

    final task = supportedTasks(
      const TaskPlatform(
        operatingSystem: 'macos',
        architecture: 'arm64',
        version: '15.0',
      ),
      {'face_landmarker'},
    ).single;
    await tester.pumpWidget(
      MaterialApp(
        home: LivePage(
          task: task,
          platform: const TaskPlatform(
            operatingSystem: 'macos',
            architecture: 'arm64',
            version: '15.0',
          ),
        ),
      ),
    );
    await tester.pump();

    // Even on a phone, Info shares the Camera / Still image switch's row.
    final mode = find.byKey(const ValueKey('face-landmarker-mode'));
    final info = find.byTooltip('About this task');
    expect(mode, findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Still image'), findsOneWidget);
    expect(
      (tester.getCenter(mode).dy - tester.getCenter(info).dy).abs(),
      lessThan(4),
    );
    expect(
      tester.getTopRight(mode).dx,
      lessThanOrEqualTo(tester.getTopLeft(info).dx),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('face-landmarker-mode-image')));
    await tester.pumpAndSettle();

    expect(find.text('Choose image'), findsOneWidget);
    expect(find.text('Choose an image to analyze.'), findsOneWidget);
    expect(
      find.text('No camera found. Connect a webcam and try again.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('face-landmarker-mode-camera')));
    await tester.pumpAndSettle();
    expect(
      find.text('No camera found. Connect a webcam and try again.'),
      findsOneWidget,
    );
  });
}

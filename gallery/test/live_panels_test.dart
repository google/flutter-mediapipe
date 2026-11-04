import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live_page.dart';
import 'package:mediapipe_gallery/ui/components.dart';
import 'package:mediapipe_gallery/ui/speed_chart.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'support/scripted_camera.dart';

// Face Landmarker runs on the CPU and the GPU here, which the Stats card's
// switch needs; macOS offers the CPU only for now (upstream-issues.md UP-057).
const _platform = TaskPlatform(operatingSystem: 'linux', architecture: 'x64');

Future<void> _pumpLivePage(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final previous = CameraPlatform.instance;
  CameraPlatform.instance = ScriptedCamera(cameras: const []);
  addTearDown(() => CameraPlatform.instance = previous);
  final task = supportedTasks(_platform, {'face_landmarker'}).single;
  await tester.pumpWidget(
    MaterialApp(
      home: LivePage(task: task, platform: _platform),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the camera demo opens idle, without capturing', (tester) async {
    final previous = CameraPlatform.instance;
    final camera = ScriptedCamera();
    CameraPlatform.instance = camera;
    addTearDown(() => CameraPlatform.instance = previous);
    final task = supportedTasks(_platform, {'face_landmarker'}).single;
    await tester.pumpWidget(
      MaterialApp(
        home: LivePage(task: task, platform: _platform),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(camera.created, isEmpty);
    expect(camera.activeStreams, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone opens Output and Stats as dialogs over the feed', (
    tester,
  ) async {
    await _pumpLivePage(tester, const Size(390, 844));
    expect(find.byType(OutputCard), findsNothing);
    expect(find.byType(StatsCard), findsNothing);

    await tester.tap(find.byTooltip('Show output'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Results appear once the camera runs.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close output'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byTooltip('Show stats'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsCard), findsOneWidget);
    await tester.tap(find.byTooltip('Close stats'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide window keeps Output under the feed and Stats inline', (
    tester,
  ) async {
    await _pumpLivePage(tester, const Size(1280, 900));
    expect(find.byType(OutputCard), findsOneWidget);
    expect(find.byTooltip('Show output'), findsNothing);

    await tester.tap(find.byTooltip('Show stats'));
    await tester.pump();
    expect(find.byType(StatsCard), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size) in [
    ('wide window', const Size(1280, 900)),
    ('phone dialog', const Size(390, 844)),
  ]) {
    testWidgets('Stats switches the task to the other delegate ($name)', (
      tester,
    ) async {
      await _pumpLivePage(tester, size);
      await tester.tap(find.byTooltip('Show stats'));
      await tester.pumpAndSettle();

      String label() => tester
          .widget<OutlineButton>(find.byKey(const ValueKey('stats-switch')))
          .label!;
      final first = label();
      expect(first, anyOf('Switch to CPU', 'Switch to GPU'));
      await tester.tap(find.text(first));
      await tester.pumpAndSettle();
      // The page now runs the other delegate, so the card offers the first.
      expect(
        label(),
        first == 'Switch to CPU' ? 'Switch to GPU' : 'Switch to CPU',
      );
      expect(find.byTooltip('Clear the chart'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

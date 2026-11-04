import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/live/live_camera_controller.dart';
import 'package:mediapipe_gallery/live/live_camera_view.dart';
import 'package:mediapipe_gallery/live/live_subjects.dart';
import 'package:mediapipe_gallery/main.dart';
import 'package:mediapipe_gallery/ui/components.dart';

import 'support/live_subject.dart';
import 'support/gallery_tiles.dart';
import 'support/supplied_camera.dart';

// Hosted runners have no physical webcam. Replace capture only: the gallery,
// controller, frame conversion, worker and Google's native CPU task are real.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native desktop camera plugin registers and enumerates devices', (
    tester,
  ) async {
    expect(Platform.isLinux || Platform.isWindows, isTrue);
    expect(
      CameraPlatform.instance.runtimeType.toString(),
      'CameraDesktopPlugin',
    );
    expect(CameraPlatform.instance.supportsImageStreaming(), isTrue);
    await tester.runAsync(() async {
      final cameras = await CameraPlatform.instance.availableCameras();
      // An empty list is expected on hosted CI; enumeration must still work.
      expect(cameras, isA<List<CameraDescription>>());
    });
  });

  final subject = LiveSubject.selected;
  testWidgets(
    'gallery ${subject.task} CPU camera: RGBA/BGRA, switching, restart and '
    'cleanup',
    (tester) async {
      final original = CameraPlatform.instance;
      final frames = await tester.runAsync(sampleFrames);
      final camera = SuppliedCamera(frames!);
      CameraPlatform.instance = camera;
      LiveCameraController<Object?>? controller;
      try {
        await tester.pumpWidget(const GalleryApp());
        final tileTitle = await scrollToGalleryTile(tester, subject.tile);
        expect(tileTitle, findsOneWidget);
        // Linux offers GPU for face and hand, and the page opens on it; this
        // test selects CPU. Windows has no GPU path.
        final gpuOffered = Platform.isLinux ? findsOneWidget : findsNothing;
        final tile = find.byKey(ValueKey('gallery-card-${subject.tile}'));
        expect(
          find.descendant(of: tile, matching: find.text('GPU')),
          gpuOffered,
        );
        await tester.tap(tileTitle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        controller = tester
            .widget<LiveCameraView>(find.byType(LiveCameraView))
            .controller;
        final live = controller;
        final firstFrames = <String, List<LivePoint>>{};
        live.addListener(() {
          final subjects = liveSubjects(live.result);
          if (live.processedFrames == 1 && subjects.isNotEmpty) {
            firstFrames.putIfAbsent(
              live.description!.name,
              () => subjects.first,
            );
          }
        });
        await selectDelegate(tester, live, Delegate.cpu);
        camera.deliverFrames = true;
        await waitForFrames(tester, live);
        await tester.pump();
        expect(find.byKey(const ValueKey('delegate-gpu')), gpuOffered);
        expect(live.delegate, Delegate.cpu);
        expect(live.frameRotationDegrees, 0);

        // Switch from the padded RGBA camera to padded BGRA without closing the
        // page. The same sample must keep its landmarks and colour order.
        await tester.tap(find.byTooltip('Switch to back camera'));
        await tester.pump();
        await waitForFrames(tester, live);
        await tester.pump();
        // The task keeps its tracking state across the camera flip, so its
        // first VIDEO result can drift slightly even with the same sample.
        // Use the tolerance from the desktop GPU camera comparison.
        final before = firstFrames['supplied-rgba']!;
        final after = firstFrames['supplied-bgra']!;
        for (var i = 0; i < before.length; i++) {
          expect(after[i].x, closeTo(before[i].x, 0.03));
          expect(after[i].y, closeTo(before[i].y, 0.03));
        }
        expect(live.description!.name, 'supplied-bgra');
        expect(camera.disposed, 1);

        expect(find.byType(StillCard), findsNothing);
        await tester.runAsync(live.stop);
        await tester.runAsync(() async {
          while (live.changing) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        });
        await tester.pump();
        expect(live.running, isFalse);
        expect(camera.activeStreams, 0);
        await tester.runAsync(live.start);
        await waitForFrames(tester, live);
        await tester.pump();
        expect(live.running, isTrue);
        expect(live.delegate, Delegate.cpu);
      } finally {
        await tester.runAsync(() async => await controller?.close());
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        CameraPlatform.instance = original;
      }
      expect(camera.activeStreams, 0);
      expect(camera.disposed, 3);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

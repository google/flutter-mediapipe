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

import 'support/delegate_control.dart';
import 'support/live_subject.dart';
import 'support/gallery_tiles.dart';
import 'support/supplied_camera.dart';

/// `works` where MediaPipe accepts this machine's GPU, `refused` where it
/// rejects it (for example an unrenamed llvmpipe). Unset skips the test.
const _expectation = String.fromEnvironment('GALLERY_GPU_EXPECT');

// GPU inference inside the running Flutter app, next to Flutter's own GL
// rendering: the gallery, controller, frame conversion, worker and Google's
// native GPU task are real; only capture is supplied.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final subject = LiveSubject.selected;
  testWidgets(
    'gallery ${subject.task} GPU camera on Linux: GPU $_expectation',
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
        await tester.tap(tileTitle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        controller = tester
            .widget<LiveCameraView>(find.byType(LiveCameraView))
            .controller;
        final live = controller;
        final firstFrames = <Delegate, List<LivePoint>>{};
        live.addListener(() {
          final subjects = liveSubjects(live.result);
          if (live.processedFrames == 1 && subjects.isNotEmpty) {
            firstFrames.putIfAbsent(live.delegate, () => subjects.first);
          }
        });
        await selectDelegate(tester, live, Delegate.cpu);
        camera.deliverFrames = true;
        await waitForFrames(tester, live);
        expect(live.delegate, Delegate.cpu);

        await tapDelegate(tester, Delegate.gpu);
        // A software renderer takes about 15 s for the first GPU frame.
        await waitForFrames(tester, live, timeout: const Duration(minutes: 3));
        await tester.pump();
        expect(live.running, isTrue);
        if (_expectation == 'works') {
          expect(live.delegate, Delegate.gpu);
          expect(live.notice, isNull);
          // Same sample, first frame of each fresh task. Face GPU and CPU
          // differ by about 0.013 on Google's own paths; Android's test
          // allows 0.03.
          final cpu = firstFrames[Delegate.cpu]!;
          final gpu = firstFrames[Delegate.gpu]!;
          for (var i = 0; i < cpu.length; i++) {
            expect(gpu[i].x, closeTo(cpu[i].x, 0.03));
            expect(gpu[i].y, closeTo(cpu[i].y, 0.03));
          }
        } else {
          expect(live.delegate, Delegate.cpu);
          expect(live.notice, contains('GPU unavailable, using CPU'));
          expect(live.notice, contains('kGpuService'));
          expect(find.textContaining('GPU unavailable'), findsOneWidget);
        }
      } finally {
        await tester.runAsync(() async => await controller?.close());
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        CameraPlatform.instance = original;
      }
      expect(camera.activeStreams, 0);
    },
    skip: !Platform.isLinux || !{'works', 'refused'}.contains(_expectation),
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live/face_overlay.dart';
import 'package:mediapipe_gallery/live_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('still image mode detects and draws a face', (tester) async {
    final setup = await tester.runAsync(() async {
      final data = await rootBundle.load('assets/samples/portrait.jpg');
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final platform = (await queryFaceLandmarkerCapabilities()).platform;
      return (bytes, platform);
    });
    expect(setup, isNotNull);
    final (bytes, platform) = setup!;
    final tasks = supportedTasks(platform, {'face_landmarker'});
    expect(tasks, hasLength(1));

    await tester.pumpWidget(
      MaterialApp(
        home: LivePage(
          task: tasks.single,
          platform: platform,
          initialStillImage: true,
          stillImagePicker: () async => XFile.fromData(
            bytes,
            name: 'portrait.jpg',
            mimeType: 'image/jpeg',
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('face-landmarker-mode')), findsOneWidget);
    expect(find.text('Still image'), findsOneWidget);
    expect(find.text('Choose image'), findsOneWidget);

    await tester.tap(find.text('Choose image'));
    await tester.pump();
    for (var attempt = 0; attempt < 240; attempt++) {
      if (find.text('1 face detected').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
    }

    expect(find.text('1 face detected'), findsOneWidget);
    final painted = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('face-landmarker-still-overlay')),
    );
    final overlay = painted.painter! as FaceOverlay;
    expect(overlay.result!.faceLandmarks, hasLength(1));
    expect(overlay.result!.faceLandmarks.single, hasLength(478));
    expect(overlay.transform.mirror, isFalse);
    expect(overlay.transform.quarterTurns, 0);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

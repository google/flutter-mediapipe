import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live/live_registry.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every camera vision demo processes a still image', (
    tester,
  ) async {
    await tester.runAsync(() async {
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
      final platform = (await queryFaceLandmarkerCapabilities()).platform;
      final tasks = supportedTasks(
        platform,
        runtimeIds,
      ).where((task) => task.live).toList();
      expect(tasks.map((task) => task.runtimeId).toSet(), runtimeIds);

      for (final entry in tasks) {
        final model = await rootBundle.load(bundledModelAsset(entry.model));
        final sample = await rootBundle.load('assets/samples/${entry.sample}');
        final codec = await ui.instantiateImageCodec(
          sample.buffer.asUint8List(sample.offsetInBytes, sample.lengthInBytes),
        );
        late final VisionImage input;
        try {
          final frame = await codec.getNextFrame();
          final image = frame.image;
          try {
            final rgba = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            expect(rgba, isNotNull, reason: entry.title);
            input = VisionImage.fromPixels(
              pixels: rgba!.buffer.asUint8List(
                rgba.offsetInBytes,
                rgba.lengthInBytes,
              ),
              width: image.width,
              height: image.height,
              format: VisionPixelFormat.rgba,
            );
          } finally {
            image.dispose();
          }
        } finally {
          codec.dispose();
        }

        final supported = entry.capabilities(platform).supportedDelegates;
        final delegate = supported.contains(Delegate.cpu)
            ? Delegate.cpu
            : supported.first;
        final demo = liveDemoFor(entry.id)!;
        final task = demo.task();
        try {
          await task.open(
            delegate,
            model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
            mode: RunningMode.image,
          );
          final result = await task.detectImage(input);
          expect(result, isNotNull, reason: entry.title);
        } finally {
          await task.close();
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}

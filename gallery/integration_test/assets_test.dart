import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live/live_camera_controller.dart';
import 'package:mediapipe_gallery/live/live_registry.dart';
import 'package:mediapipe_gallery/main.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';

/// The gallery's preparer (`tool/gallery_builder`) chooses what the app
/// bundles per target, so an asset a screen asks for by name can silently not
/// be there. These check the bundle the app was actually built with.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every visible tile can load its model and sample', (_) async {
    final assets = await GalleryAssets.unpack();
    final platform = (await queryObjectDetectorCapabilities()).platform;
    final tasks = supportedTasks(
      platform,
      assets.bundledTasks,
    ).where((task) => task.hasOwnPage).toList();
    expect(tasks, isNotEmpty, reason: 'no tile is visible to check');
    for (final task in tasks) {
      // Decision Maker's pages download their models on first use.
      if (!task.downloadsModel) {
        await expectLater(
          rootBundle.load(bundledModelAsset(task.model)),
          completes,
          reason: '${task.id} model',
        );
      }
      // Text tiles take typed input and bundle no sample.
      if (task.sample.isNotEmpty) {
        await expectLater(
          rootBundle.load('assets/samples/${task.sample}'),
          completes,
          reason: '${task.id} sample',
        );
      }
    }
  });

  testWidgets('every live demo loads its model before touching a camera', (
    _,
  ) async {
    final assets = await GalleryAssets.unpack();
    final platform = (await queryObjectDetectorCapabilities()).platform;
    final live = supportedTasks(
      platform,
      assets.bundledTasks,
    ).where((task) => task.demo == GalleryDemo.live).toList();
    if (live.isEmpty) {
      markTestSkipped('no live tile on this platform');
      return;
    }
    // Only the first live tile runs here: loading a second tile whose task
    // binds a different native asset would hit the duplicate-runtime abort
    // that runtime_test.dart documents.
    for (final task in live.take(1)) {
      final controller = LiveCameraController<Object?>(
        liveDemoFor(task.id)!.task(),
      );
      addTearDown(controller.dispose);
      // The model is loaded before the camera is opened, so this reaches the
      // asset without needing a real device. Opening a camera that does not
      // exist is expected to fail; failing to find the model is the regression.
      // start() reports failures on the controller rather than throwing, which
      // is how this surfaced in the app as a message instead of a crash.
      await controller.start(
        description: const CameraDescription(
          name: 'gallery-integration-test',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 0,
        ),
        model: task.model,
      );
      expect(
        controller.error ?? '',
        isNot(contains('Unable to load asset')),
        reason: '${task.id} asked for a model the bundle does not have',
      );
    }
  });
}

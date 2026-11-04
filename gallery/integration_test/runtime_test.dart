import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live/live_registry.dart';
import 'package:mediapipe_gallery/main.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';

/// Opening one tile and then another must not take the process down.
///
/// Task bindings carry their own native asset id: face tasks bind
/// `face_landmarker.dylib` while every other task binds `vision.dylib`. A
/// runtime serving both ids must still be loaded once, or its graph registry
/// aborts on the second registration: the desktop wheels load one image for
/// both ids, Google's macOS monolith is bundled once as `vision.dylib` with
/// face calling through it, and the mobile SDK adapters serve every id from one
/// image. An abort is native, not a Dart exception, so it kills the test
/// process rather than failing an expectation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tiles that use different native assets coexist', (_) async {
    final assets = await GalleryAssets.unpack();
    final platform = (await queryObjectDetectorCapabilities()).platform;
    final tiles = supportedTasks(
      platform,
      assets.bundledTasks,
    ).where((task) => task.demo == GalleryDemo.live).toList();
    expect(tiles.length, greaterThan(1), reason: 'need two live tiles');

    // Visit every live tile in one process, exactly as a user moving through
    // the grid does. Each task is fully disposed before the next opens, so a
    // failure here is about loaded native images, not about task lifetime.
    final visited = <String>[];
    for (final tile in tiles) {
      final task = liveDemoFor(tile.id)!.task();
      final model = await rootBundle.load(bundledModelAsset(tile.model));
      final delegates = tile.capabilities(platform).supportedDelegates;
      await task.open(
        delegates.contains(Delegate.cpu) ? Delegate.cpu : delegates.first,
        model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
      );
      // The camera's mode: listen, then submit one frame.
      final first = task.results.first;
      task.submit(
        VisionImage.fromFile(assets.path(tile.sample)),
        1,
        rotationDegrees: 0,
      );
      final result = await first;
      expect(result.timestamp, 1, reason: tile.id);
      expect(result.result, isNotNull, reason: tile.id);
      await task.close();
      visited.add(tile.id);
    }
    expect(visited, hasLength(tiles.length));
    // The record of which tiles this platform opened.
    // ignore: avoid_print
    print('RUNTIME_TILES ${visited.join(',')}');
  });

  // Text and audio run on core's shared runtime. Vision bindings must resolve
  // to that same library when both are present in one desktop process.
  testWidgets('text and audio answer in the same process', (tester) async {
    final assets = await GalleryAssets.unpack();
    final bundled = assets.bundledTasks;
    if (!bundled.contains('text_classifier') &&
        !bundled.contains('audio_classifier')) {
      markTestSkipped('This target bundles no text or audio task.');
      return;
    }
    await tester.runAsync(() async {
      if (bundled.contains('text_classifier')) {
        final classifier = await TextClassifier.create(
          TextClassifierOptions(
            modelBytes: await loadAssetBytes(
              bundledModelFile('bert_classifier.tflite'),
            ),
          ),
        );
        try {
          final result = await classifier.classify('What a wonderful day!');
          expect(
            result.classifications.first.categories.first.categoryName,
            'positive',
          );
        } finally {
          await classifier.dispose();
        }
      }
      if (bundled.contains('audio_classifier')) {
        final classifier = await AudioClassifier.create(
          AudioClassifierOptions(
            modelBytes: await loadAssetBytes(bundledModelFile('yamnet.tflite')),
          ),
        );
        try {
          final chunks = await classifier.classify(
            decodeWav(
              await loadAssetBytes('assets/samples/speech_16000_hz_mono.wav'),
            ),
          );
          expect(
            chunks.first.classifications.first.categories.first.categoryName,
            'Speech',
          );
        } finally {
          await classifier.dispose();
        }
      }
    });
  });

  testWidgets('stateful segmenter opens after vision, text, and audio', (
    tester,
  ) async {
    final assets = await GalleryAssets.unpack();
    if (!assets.bundledTasks.contains('interactive_segmenter')) {
      markTestSkipped('This target bundles no stateful segmenter.');
      return;
    }
    await tester.runAsync(() async {
      final model = await rootBundle.load(
        bundledModelFile('interactive_segmentation.task'),
      );
      final task = await InteractiveSegmenter.create(
        InteractiveSegmenterOptions(
          modelBytes: model.buffer.asUint8List(
            model.offsetInBytes,
            model.lengthInBytes,
          ),
        ),
      );
      try {
        await task.setImage(VisionImage.fromFile(assets.path('animals.jpg')));
        final mask = await task.segment([
          Stroke(
            brushMode: BrushMode.positive,
            points: [NormalizedKeypoint(x: 0.42, y: 0.6)],
          ),
        ]);
        expect(mask.width, greaterThan(0));
        expect(mask.height, greaterThan(0));
        expect(mask.confidence.length, mask.width * mask.height);
        expect(mask.confidence.any((value) => value > 0.5), isTrue);
      } finally {
        await task.dispose();
      }
    });
  });
}

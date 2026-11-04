import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/main.dart';
import 'package:mediapipe_gallery/segment_page.dart';
import 'package:mediapipe_gallery/ui/components.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';

/// A segmenter that records every history and answers a one-pixel mask, or
/// throws [failure] while it is set.
final class _FakeSegmenter implements InteractiveSegmenterBackend {
  final calls = <List<Stroke>>[];
  int images = 0;
  Object? failure;

  @override
  Future<void> setImage(VisionImage image) async => images++;

  @override
  Future<ConfidenceMask> segment(List<Stroke> strokes) async {
    calls.add(strokes);
    if (failure case final failure?) throw failure;
    return ConfidenceMask(
      width: 1,
      height: 1,
      confidence: Float32List.fromList([1]),
    );
  }

  @override
  Future<void> dispose() async {}
}

/// The Segment page over a fake segmenter: Google's three brushes, the
/// gestures each takes, and the Selection card's count of finished strokes.
void main() {
  const platform = TaskPlatform(
    operatingSystem: 'macos',
    architecture: 'arm64',
    version: '15.0',
  );
  late _FakeSegmenter backend;
  late Directory samples;

  setUpAll(() async {
    // Core caches its platform query, and a future first made inside one
    // test's fake clock would never complete in the next test: make it here.
    await queryInteractiveSegmenterCapabilities();
    // The page reads its sample as a file, as the native task does.
    samples = Directory.systemTemp.createTempSync('gallery-samples-');
    final bytes = await rootBundle.load('assets/samples/animals.jpg');
    File('${samples.path}/animals.jpg').writeAsBytesSync(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  });

  setUp(() {
    // The page passes the model's pin, which core copies out of the bundle
    // into its cache; tests have no application support directory. A fresh
    // cache per test keeps the lookup on the bundled path: verifying a
    // cached copy streams 30 MB through the test's pumped event loop, one
    // chunk per pump.
    ModelStore.debugCacheDirectory = Directory.systemTemp
        .createTempSync('gallery-models-')
        .path;
    backend = _FakeSegmenter();
    interactiveSegmenterBackendFactory = (_) async => backend;
  });
  tearDown(() => interactiveSegmenterBackendFactory = null);

  Future<bool> bundled() async {
    try {
      await rootBundle.load(
        'assets/mediapipe/${VisionModels.interactiveSegmenter.sha256}',
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// Pumps real time until [done]: the page decodes its picture and masks
  /// off the test clock.
  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 800; i++) {
      await tester.pump();
      if (done()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
    }
    fail('The Segment page did not reach the expected state.');
  }

  final canvas = find.byKey(const ValueKey('segment-canvas'));
  final brushes = find.byWidgetPredicate(
    (widget) => widget is Segmented<BrushMode>,
  );

  /// The page with its picture shown and the brushes enabled.
  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final task = supportedTasks(platform, {'interactive_segmenter'}).single;
    await tester.pumpWidget(
      MaterialApp(
        home: SegmentPage(
          task: task,
          assets: GalleryAssets(samples, const {
            'tasks': ['interactive_segmenter'],
          }),
          platform: platform,
        ),
      ),
    );
    await until(
      tester,
      () =>
          canvas.evaluate().isNotEmpty &&
          tester.widget<Segmented<BrushMode>>(brushes).onChanged != null,
    );
  }

  Future<void> pickBrush(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey('brush-$name')));
    await tester.pump();
  }

  testWidgets("offers Google's three brushes, Include first", (tester) async {
    if (!await bundled()) {
      markTestSkipped('This build bundles no Interactive Segmenter.');
      return;
    }
    await openPage(tester);
    expect(backend.images, 1);
    final control = tester.widget<Segmented<BrushMode>>(brushes);
    expect(control.segments.map((s) => s.label), [
      'Include',
      'Exclude',
      'Lasso',
    ]);
    expect(control.selected, BrushMode.positive);
    expect(
      find.text('Tap or drag over a subject to include it.'),
      findsWidgets,
    );
    await pickBrush(tester, 'lasso');
    expect(
      find.text('Draw a shape around a subject to select it.'),
      findsWidgets,
    );
    await pickBrush(tester, 'negative');
    expect(find.text('Tap or drag over an area to exclude it.'), findsWidgets);
    expect(backend.calls, isEmpty);
  });

  testWidgets('Exclude is segmented while drawn and counted when done', (
    tester,
  ) async {
    if (!await bundled()) {
      markTestSkipped('This build bundles no Interactive Segmenter.');
      return;
    }
    await openPage(tester);
    await pickBrush(tester, 'negative');
    await tester.timedDrag(
      canvas,
      const Offset(160, 0),
      const Duration(milliseconds: 400),
    );
    await until(tester, () => find.text('1 exclude').evaluate().isNotEmpty);
    expect(backend.calls, isNotEmpty);
    // The first history carried the stroke as it was being drawn.
    expect(backend.calls.first.single.brushMode, BrushMode.negative);
    expect(backend.calls.first.single.isCompleted, isFalse);
    await until(tester, () => backend.calls.last.single.isCompleted);
    expect(backend.calls.last.single.brushMode, BrushMode.negative);
    expect(backend.calls.last.single.points.length, greaterThan(1));
  });

  testWidgets('a lasso ignores taps, waits for the pointer, and stays open', (
    tester,
  ) async {
    if (!await bundled()) {
      markTestSkipped('This build bundles no Interactive Segmenter.');
      return;
    }
    await openPage(tester);
    await pickBrush(tester, 'lasso');
    await tester.tap(canvas);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(backend.calls, isEmpty);
    final center = tester.getCenter(canvas);
    final gesture = await tester.startGesture(center + const Offset(-120, -80));
    for (final corner in const [
      Offset(120, -80),
      Offset(120, 80),
      Offset(-120, 80),
    ]) {
      await gesture.moveTo(center + corner);
      await tester.pump(const Duration(milliseconds: 30));
    }
    // Nothing is segmented while the lasso is drawn.
    expect(backend.calls, isEmpty);
    await gesture.up();
    await until(tester, () => find.text('1 lasso').evaluate().isNotEmpty);
    await until(tester, () => backend.calls.isNotEmpty);
    final stroke = backend.calls.single.single;
    expect(stroke.brushMode, BrushMode.lasso);
    expect(stroke.isCompleted, isTrue);
    expect(stroke.points.length, greaterThanOrEqualTo(3));
    // Sent as drawn: Google reads the box, so the outline is not closed.
    expect(
      stroke.points.first.x == stroke.points.last.x &&
          stroke.points.first.y == stroke.points.last.y,
      isFalse,
    );
  });

  testWidgets(
    'the Selection card counts strokes by brush, and undo drops one',
    (tester) async {
      if (!await bundled()) {
        markTestSkipped('This build bundles no Interactive Segmenter.');
        return;
      }
      await openPage(tester);
      await tester.tap(canvas);
      await until(tester, () => find.text('1 include').evaluate().isNotEmpty);
      await pickBrush(tester, 'negative');
      await tester.timedDrag(
        canvas,
        const Offset(160, 0),
        const Duration(milliseconds: 400),
      );
      await until(
        tester,
        () => find.text('1 include · 1 exclude').evaluate().isNotEmpty,
      );
      await tester.tap(find.byTooltip('Undo stroke'));
      await until(tester, () => find.text('1 include').evaluate().isNotEmpty);
      expect(find.text('1 include · 1 exclude'), findsNothing);
      // Undoing the last stroke resubmits the shorter history.
      expect(backend.calls.last.single.brushMode, BrushMode.positive);
    },
  );

  testWidgets(
    'a failed request shows over the picture, and the next stroke retries',
    (tester) async {
      if (!await bundled()) {
        markTestSkipped('This build bundles no Interactive Segmenter.');
        return;
      }
      await openPage(tester);
      final failure = find.textContaining('WebGL context lost');
      backend.failure = StateError('WebGL context lost');
      await tester.tap(canvas);
      await until(tester, () => failure.evaluate().isNotEmpty);
      // Only a banner says what failed: the picture, the stroke and the
      // brushes stay.
      expect(canvas, findsOneWidget);
      expect(find.text('1 include'), findsOneWidget);
      expect(tester.widget<Segmented<BrushMode>>(brushes).onChanged, isNotNull);
      backend.failure = null;
      await tester.tap(canvas);
      await until(tester, () => failure.evaluate().isEmpty);
      expect(find.text('2 include'), findsOneWidget);
      expect(backend.calls.last, hasLength(2));
    },
  );
}

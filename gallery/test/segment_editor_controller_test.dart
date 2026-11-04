import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/segment/editor_controller.dart';
import 'package:mediapipe_gallery/segment/mask_overlay.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

class FakeBackend implements SegmentationBackend {
  final calls = <List<Stroke>>[];
  final results = <Completer<ConfidenceMask>>[];
  int images = 0;
  int closed = 0;

  @override
  Future<void> setImage(VisionImage image) async => images++;
  @override
  Future<ConfidenceMask> segment(List<Stroke> strokes) {
    calls.add(strokes);
    final result = Completer<ConfidenceMask>();
    results.add(result);
    return result.future;
  }

  @override
  Future<void> dispose() async => closed++;

  void finish(int index, [double confidence = 1]) => results[index].complete(
    ConfidenceMask(
      width: 1,
      height: 1,
      confidence: Float32List.fromList([confidence]),
    ),
  );
}

/// A backend whose image load fails while [fail] is set.
class _FailingImageBackend extends FakeBackend {
  bool fail = true;

  @override
  Future<void> setImage(VisionImage image) async {
    if (fail) throw StateError('decode failed');
    await super.setImage(image);
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

/// What debugPrint prints until the test ends.
List<String> capturePrints() {
  final printed = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => printed.add(message!);
  addTearDown(() => debugPrint = original);
  return printed;
}

NormalizedKeypoint point(double x, [double y = 0.5]) =>
    NormalizedKeypoint(x: x, y: y);
VisionImage input() => VisionImage.fromPixels(
  pixels: Uint8List(3),
  width: 1,
  height: 1,
  format: VisionPixelFormat.rgb,
);

/// The middle of a stroke's points, where a tap's ring is centered (the ring
/// repeats its first point to close, so the mean is off by under 0.001).
double centerX(Stroke stroke) =>
    stroke.points.map((p) => p.x).reduce((a, b) => a + b) /
    stroke.points.length;

void main() {
  late FakeBackend backend;
  late EditorController editor;
  setUp(() async {
    backend = FakeBackend();
    editor = EditorController(backend);
    await editor.loadImage(input());
  });
  tearDown(() async {
    for (var i = 0; i < backend.results.length; i++) {
      if (!backend.results[i].isCompleted) backend.finish(i);
    }
    await editor.close();
    editor.dispose();
  });

  test(
    'drag coalesces to latest complete history without parallel inference',
    () async {
      editor.begin(point(0.2));
      await tick();
      expect(backend.calls, hasLength(1));
      expect(backend.calls.first.single.isCompleted, isFalse);
      for (var i = 21; i < 80; i++) {
        editor.extend(point(i / 100));
      }
      editor.end();
      expect(backend.calls, hasLength(1));
      expect(editor.coalescedRequests, greaterThan(50));
      backend.finish(0, 0.2);
      await tick();
      expect(editor.mask, isNull);
      expect(backend.calls, hasLength(2));
      expect(backend.calls.last.single.isCompleted, isTrue);
      // Long enough to be sent as drawn.
      expect(backend.calls.last.single.points, hasLength(60));
      expect(backend.calls.last.single.points.last.x, 0.79);
      // The active native snapshot was never mutated by later pointer events:
      // it is still the ring around the first point.
      expect(backend.calls.first.single.points, hasLength(13));
      expect(centerX(backend.calls.first.single), closeTo(0.2, 1e-3));
      backend.finish(1, 0.8);
      await tick();
      expect(editor.mask!.confidence.single, closeTo(0.8, 1e-6));
      expect(editor.completedRequests, 2);
      await tick();
      expect(backend.calls, hasLength(2));
    },
  );

  test('a tap is sent as a small ring, since a point draws nothing on GPU', () {
    editor.begin(point(0.5, 0.5));
    final ring = editor.strokes.single.points;
    expect(ring, hasLength(13));
    for (final p in ring) {
      expect((p.x - 0.5).abs(), lessThanOrEqualTo(0.01 + 1e-9));
      expect((p.y - 0.5).abs(), lessThanOrEqualTo(0.01 + 1e-9));
    }
    // A ring at the edge stays inside the picture.
    editor
      ..end()
      ..begin(point(0, 1));
    for (final p in editor.strokes.last.points) {
      expect(p.x, inInclusiveRange(0, 1));
      expect(p.y, inInclusiveRange(0, 1));
    }
  });

  test('image replacement drops queued history and obsolete mask', () async {
    editor.begin(point(0.2));
    await tick();
    editor.extend(point(0.3));
    await editor.loadImage(input());
    editor
      ..begin(point(0.7))
      ..end();
    backend.finish(0);
    await tick();
    expect(editor.mask, isNull);
    expect(backend.calls, hasLength(2));
    expect(centerX(backend.calls.last.single), closeTo(0.7, 1e-3));
    backend.finish(1);
    await tick();
    expect(editor.mask, isNotNull);
    expect(backend.images, 2);
  });

  test(
    'undo resubmits full shorter history; clear never segments empty',
    () async {
      editor
        ..begin(point(0.2))
        ..end();
      await tick();
      backend.finish(0);
      await tick();
      editor.brush = BrushMode.negative;
      editor
        ..begin(point(0.4))
        ..end();
      await tick();
      expect(backend.calls.last, hasLength(2));
      expect(backend.calls.last.last.brushMode, BrushMode.negative);
      backend.finish(1);
      await tick();
      editor.undo();
      await tick();
      expect(backend.calls.last, hasLength(1));
      backend.finish(2);
      await tick();
      editor.undo();
      await tick();
      expect(editor.mask, isNull);
      expect(editor.strokes, isEmpty);
      expect(backend.calls, hasLength(3));
      expect(backend.images, 2);
    },
  );

  test(
    'a lasso is drawn until the pointer lifts, then sent as drawn',
    () async {
      editor.brush = BrushMode.lasso;
      editor
        ..begin(point(0.1, 0.1))
        ..extend(point(0.9, 0.1))
        ..extend(point(0.5, 0.9));
      await tick();
      // Google's CPU graph reads an unfinished lasso differently, so nothing
      // is segmented while it is drawn; the painter still sees the points.
      expect(backend.calls, isEmpty);
      expect(editor.activePoints, hasLength(3));
      expect(editor.activeBrush, BrushMode.lasso);
      expect(editor.canUndo, isTrue);
      editor.end();
      await tick();
      final stroke = backend.calls.single.single;
      expect(stroke.brushMode, BrushMode.lasso);
      expect(stroke.isCompleted, isTrue);
      // Google reads the box around the points, so the outline is not closed.
      expect(stroke.points, hasLength(3));
      expect(stroke.points.last.x, 0.5);
      expect(editor.strokeCounts, {BrushMode.lasso: 1});
      backend.finish(0);
      await tick();
      expect(editor.mask, isNotNull);
    },
  );

  test(
    'a lasso shorter than the minimum is dropped, so a tap draws none',
    () async {
      editor.brush = BrushMode.lasso;
      editor
        ..begin(point(0.5, 0.5))
        ..extend(point(0.51, 0.5))
        ..end();
      await tick();
      expect(backend.calls, isEmpty);
      expect(editor.strokes, isEmpty);
      expect(editor.canUndo, isFalse);
      expect(editor.strokeCounts, isEmpty);
    },
  );

  test(
    'an Exclude stroke is sent while drawn, and counted when done',
    () async {
      editor
        ..begin(point(0.2))
        ..end();
      await tick();
      backend.finish(0);
      await tick();
      editor.brush = BrushMode.negative;
      editor.begin(point(0.6));
      await tick();
      expect(backend.calls, hasLength(2));
      expect(backend.calls.last.last.brushMode, BrushMode.negative);
      expect(backend.calls.last.last.isCompleted, isFalse);
      expect(editor.strokeCounts, {BrushMode.positive: 1});
      for (var i = 61; i < 70; i++) {
        editor.extend(point(i / 100));
      }
      editor.end();
      backend.finish(1);
      await tick();
      expect(backend.calls.last.last.isCompleted, isTrue);
      expect(editor.strokeCounts, {
        BrushMode.positive: 1,
        BrushMode.negative: 1,
      });
      expect(editor.completedStrokes, hasLength(2));
      backend.finish(2);
      await tick();
    },
  );

  test('clear during inference prevents late selection reappearing', () async {
    editor.begin(point(0.2));
    await tick();
    await editor.clear();
    backend.finish(0);
    await tick();
    expect(editor.mask, isNull);
    expect(editor.ready, isTrue);
    expect(editor.strokes, isEmpty);
    expect(backend.calls, hasLength(1));
  });

  test('a failed request keeps the picture, strokes and mask; the next stroke '
      'retries and its success clears the error', () async {
    final printed = capturePrints();
    editor
      ..begin(point(0.2))
      ..end();
    await tick();
    backend.finish(0, 0.25);
    await tick();
    final kept = editor.mask;
    editor
      ..brush = BrushMode.negative
      ..begin(point(0.3))
      ..end();
    await tick();
    backend.results[1].completeError(StateError('lost context'));
    await tick();
    expect(editor.ready, isTrue);
    expect(editor.error, contains('lost context'));
    expect(editor.mask, same(kept));
    expect(editor.completedStrokes, hasLength(2));
    expect(printed, [
      'Segment: segment failed for [positive 13 points, negative 13 '
          'points]: Bad state: lost context',
    ]);
    // The same failure again is not printed again.
    editor
      ..begin(point(0.4))
      ..end();
    await tick();
    backend.results[2].completeError(StateError('lost context'));
    await tick();
    expect(printed, hasLength(1));
    editor
      ..begin(point(0.5))
      ..end();
    await tick();
    expect(backend.calls.last, hasLength(4));
    // Each retry gave Google's graph the image again first.
    expect(backend.images, 3);
    backend.finish(3);
    await tick();
    expect(editor.error, isNull);
    expect(editor.mask, isNot(same(kept)));
  });

  test('a failed image load stops the editor until the next load', () async {
    final failing = _FailingImageBackend();
    final broken = EditorController(failing, debugLabel: 'Segment GPU');
    addTearDown(broken.close);
    final printed = capturePrints();
    await broken.loadImage(input());
    expect(broken.ready, isFalse);
    expect(broken.error, contains('decode failed'));
    expect(printed, ['Segment GPU: setImage failed: Bad state: decode failed']);
    failing.fail = false;
    await broken.loadImage(input());
    expect(broken.ready, isTrue);
    expect(broken.error, isNull);
  });

  test(
    'failure is reset by clear; close drains once without notification',
    () async {
      capturePrints();
      editor
        ..begin(point(0.2))
        ..end();
      await tick();
      backend.results[0].completeError(StateError('decoder failure'));
      await tick();
      expect(editor.ready, isTrue);
      expect(editor.error, contains('decoder failure'));
      await editor.clear();
      expect(editor.error, isNull);
      editor
        ..begin(point(0.3))
        ..end();
      await tick();
      var notifications = 0;
      editor.addListener(() => notifications++);
      final closing = editor.close();
      expect(editor.close(), same(closing));
      backend.finish(1);
      await closing;
      expect(backend.closed, 1);
      expect(notifications, 0);
      expect(editor.mask, isNull);
    },
  );

  test(
    'threshold changes only overlay bytes, preserving original confidence',
    () {
      final values = Float32List.fromList([0, 0.25, 0.5, 1]);
      final low = maskRgba(values, 0.5);
      final high = maskRgba(values, 0.75);
      expect([low[3], low[7], low[11], low[15]], [0, 0, 115, 115]);
      expect([high[3], high[7], high[11], high[15]], [0, 0, 0, 115]);
      expect(values, [0, 0.25, 0.5, 1]);
      expect(low.sublist(8, 12), [30, 107, 82, 115]);
    },
  );
}

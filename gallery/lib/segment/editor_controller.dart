import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

abstract interface class SegmentationBackend {
  Future<void> setImage(VisionImage image);
  Future<ConfidenceMask> segment(List<Stroke> strokes);
  Future<void> dispose();
}

class NativeSegmentationBackend implements SegmentationBackend {
  NativeSegmentationBackend(this.task);
  final InteractiveSegmenter task;

  @override
  Future<void> setImage(VisionImage image) => task.setImage(image);
  @override
  Future<ConfidenceMask> segment(List<Stroke> strokes) => task.segment(strokes);
  @override
  Future<void> dispose() => task.dispose();
}

/// One active inference and one replaceable pending stroke snapshot.
///
/// Image changes, clear and undo invalidate obsolete results immediately.
/// MediaPipe always receives the complete history. Include and Exclude
/// strokes are sent while they are drawn, since Google reads them the same
/// finished or not; a lasso is sent when the pointer lifts, as Google's
/// samples do, because Google's CPU graph reads an unfinished lasso
/// differently from the finished one.
///
/// A failed request keeps the image, the strokes and the last mask: [error]
/// says what failed, the next stroke sets the image again and asks again,
/// and a success clears it.
/// Failures are printed with [debugLabel] and the history sent, so a
/// browser's console keeps them after the page has moved on.
class EditorController extends ChangeNotifier {
  EditorController(this._backend, {this.debugLabel = 'Segment'});
  final SegmentationBackend _backend;

  /// Names this editor in the failures it prints, such as its delegate.
  final String debugLabel;
  final _completed = <Stroke>[];
  List<NormalizedKeypoint>? _active;
  BrushMode _activeBrush = BrushMode.positive;
  BrushMode brush = BrushMode.positive;
  VisionImage? _input;
  ConfidenceMask? mask;
  String? error;
  bool ready = false;
  bool _closed = false;
  int _generation = 0;
  int _revision = 0;
  ({int generation, int revision, List<Stroke> strokes})? _pending;
  Future<void>? _draining;

  /// A request failed on this image: the next one sets the image again.
  bool _stale = false;
  Future<void>? _loading;
  Future<void>? _closing;
  double? lastInferenceMs;
  int completedRequests = 0;
  int coalescedRequests = 0;

  bool get canUndo => _completed.isNotEmpty || _active != null;
  List<NormalizedKeypoint> get activePoints => List.unmodifiable(_active ?? []);

  /// The brush of the stroke being drawn, else the selected one.
  BrushMode get activeBrush => _active != null ? _activeBrush : brush;

  /// The strokes the pointer has finished, in order.
  List<Stroke> get completedStrokes => List.unmodifiable(_completed);

  /// How many finished strokes each brush drew, for brushes that drew any.
  Map<BrushMode, int> get strokeCounts => {
    for (final mode in BrushMode.values)
      if (_completed.any((stroke) => stroke.brushMode == mode))
        mode: _completed.where((stroke) => stroke.brushMode == mode).length,
  };

  /// The history MediaPipe receives: finished strokes, and an Include or
  /// Exclude stroke still being drawn. A lasso waits for the pointer to lift.
  List<Stroke> get strokes => List.unmodifiable([
    ..._completed,
    if (_active case final points?
        when points.isNotEmpty && _activeBrush != BrushMode.lasso)
      Stroke(
        brushMode: _activeBrush,
        points: _brushPoints(points),
        isCompleted: false,
      ),
  ]);

  /// Google's web sample drops strokes shorter than this (normalized length).
  /// A shorter Include or Exclude stroke is sent as a ring around its points;
  /// a shorter lasso is dropped, so a tap in lasso mode selects nothing.
  static const minimumStrokeLength = 0.05;

  static double _length(List<NormalizedKeypoint> points) {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += math.sqrt(
        math.pow(points[i].x - points[i - 1].x, 2) +
            math.pow(points[i].y - points[i - 1].y, 2),
      );
    }
    return length;
  }

  /// A tap or short brush stroke as a small ring around its points. Google's
  /// WebGL graph draws strokes as line segments, so a single point draws
  /// nothing there and the segmenter returns its default mask; the CPU graph
  /// reads the ring and the point alike on all but a few hundredths of a
  /// percent of pixels.
  static List<NormalizedKeypoint> _brushPoints(
    List<NormalizedKeypoint> points,
  ) {
    if (_length(points) >= minimumStrokeLength) return points;
    final x = points.map((p) => p.x).reduce((a, b) => a + b) / points.length;
    final y = points.map((p) => p.y).reduce((a, b) => a + b) / points.length;
    const radius = 0.01;
    return [
      for (var i = 0; i <= 12; i++)
        NormalizedKeypoint(
          x: (x + radius * math.cos(i * math.pi / 6)).clamp(0.0, 1.0),
          y: (y + radius * math.sin(i * math.pi / 6)).clamp(0.0, 1.0),
        ),
    ];
  }

  Future<void> loadImage(VisionImage image) {
    if (_closed) return Future.value();
    final generation = ++_generation;
    _revision++;
    _input = image;
    _pending = null;
    _stale = false;
    _completed.clear();
    _active = null;
    mask = null;
    error = null;
    lastInferenceMs = null;
    ready = false;
    _notify();
    return _loading = _load(image, generation);
  }

  Future<void> _load(VisionImage image, int generation) async {
    try {
      await _backend.setImage(image);
      if (!_closed && generation == _generation) ready = true;
    } catch (failure) {
      debugPrint('$debugLabel: setImage failed: $failure');
      if (!_closed && generation == _generation) error = failure.toString();
    }
    _notify();
  }

  void begin(NormalizedKeypoint point) {
    if (!ready || _closed || _active != null) return;
    _activeBrush = brush;
    _active = [point];
    // A lasso is drawn, not segmented, until the pointer lifts.
    if (_activeBrush == BrushMode.lasso) {
      _notify();
    } else {
      _changed();
    }
  }

  void extend(NormalizedKeypoint point) {
    final points = _active;
    if (points == null || !ready || _closed) return;
    final previous = points.last;
    if (previous.x == point.x && previous.y == point.y) return;
    points.add(point);
    if (_activeBrush == BrushMode.lasso) {
      _notify();
    } else {
      _changed();
    }
  }

  void end() {
    final points = _active;
    if (points == null || _closed) return;
    _active = null;
    if (_activeBrush == BrushMode.lasso) {
      if (_length(points) < minimumStrokeLength) {
        // A tap or a tiny drag is no lasso. Nothing was sent, so nothing
        // changes but the drawing.
        _notify();
        return;
      }
      // Sent as drawn: Google reads the box around the points, so closing
      // the outline would change nothing.
      _completed.add(Stroke(brushMode: BrushMode.lasso, points: points));
    } else {
      _completed.add(
        Stroke(brushMode: _activeBrush, points: _brushPoints(points)),
      );
    }
    _changed();
  }

  void undo() {
    if (!ready || !canUndo || _closed) return;
    if (_active != null) {
      _active = null;
    } else {
      _completed.removeLast();
    }
    if (_completed.isEmpty) {
      unawaited(clear());
    } else {
      _changed();
    }
  }

  Future<void> clear() async {
    if (_input case final image?) await loadImage(image);
  }

  void _changed() {
    _revision++;
    final history = strokes;
    if (history.isNotEmpty) {
      if (_pending != null) coalescedRequests++;
      _pending = (
        generation: _generation,
        revision: _revision,
        strokes: history,
      );
      _startDrain();
    } else {
      _pending = null;
    }
    _notify();
  }

  void _startDrain() {
    if (_draining == null && _pending != null && ready && !_closed) {
      _draining = _drain();
    }
  }

  Future<void> _drain() async {
    // Let _draining be assigned before a synchronously completing fake backend.
    await Future<void>.value();
    try {
      while (!_closed && ready && _pending != null) {
        final request = _pending!;
        _pending = null;
        try {
          // A failed request can leave Google's graph needing the image
          // again, so the next one sends it first.
          if (_stale) {
            _stale = false;
            await _backend.setImage(_input!);
          }
          final watch = Stopwatch()..start();
          final result = await _backend.segment(request.strokes);
          completedRequests++;
          if (!_closed &&
              request.generation == _generation &&
              request.revision == _revision) {
            mask = result;
            lastInferenceMs = watch.elapsedMicroseconds / 1000;
            error = null;
          }
        } catch (failure) {
          final message = failure.toString();
          // The first of a run of failures is printed with what was sent,
          // not one line per pointer move after it.
          if (message != error) {
            debugPrint(
              '$debugLabel: segment failed for '
              '[${_describe(request.strokes)}]: $message',
            );
          }
          // The image and the history stay, so the next stroke retries; a
          // newer history already pending goes out now.
          if (!_closed && request.generation == _generation) {
            error = message;
            _stale = true;
          }
        }
        _notify();
      }
    } finally {
      _draining = null;
      _startDrain();
      _notify();
    }
  }

  /// "positive 13 points, negative 8 points in progress", for the failure
  /// log.
  static String _describe(List<Stroke> strokes) => [
    for (final stroke in strokes)
      '${stroke.brushMode.name} ${stroke.points.length} points'
          '${stroke.isCompleted ? '' : ' in progress'}',
  ].join(', ');

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> close() {
    _closed = true;
    ready = false;
    _generation++;
    _pending = null;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    await _loading;
    await _draining;
    await _backend.dispose();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}

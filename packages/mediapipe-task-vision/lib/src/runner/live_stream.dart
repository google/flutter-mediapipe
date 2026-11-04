/// Google's LIVE_STREAM, emulated on the task's VIDEO graph: the flow limiter
/// Google puts in front of the graph, here in front of the runtime instead,
/// so it holds on every platform, the browser included. Both modes turn on
/// the same tracking and smoothing, so a frame that runs gets the result it
/// would get from Google's LIVE_STREAM.
library;

import 'dart:async';

import 'package:mediapipe_core/mediapipe_core.dart';

import '../types/vision_types.dart';
import 'browser_frames.dart';
import 'checks.dart';

/// A frame the limiter accepted: the image, its rotation, its timestamp and
/// the region of interest of the tasks that accept one.
typedef LiveFrame = (VisionImage, int, int, VisionRegionOfInterest?);

/// One frame in flight and one queued, as Google's `FlowLimiterCalculator`
/// is configured for LIVE_STREAM (`max_in_flight: 1`, `max_in_queue: 1`): a
/// newer frame replaces the queued one, which is dropped and counted. A
/// dropped frame never leaves the calling isolate, so it costs no copy to a
/// worker, no platform channel call and, in browsers, no transfer.
final class LiveStreamLimiter<R> {
  /// Checks frames with [_checks] and runs the accepted ones with [_run].
  LiveStreamLimiter(this._checks, this._run);

  final VisionTaskChecks _checks;
  final Future<R> Function(LiveFrame frame) _run;
  late final _results = StreamController<R>(onListen: () => _listened = true);
  var _listened = false;
  var _busy = false;
  LiveFrame? _queued;
  Completer<void>? _idle;

  /// Frames accepted but never run: replaced in the queue by a newer frame,
  /// or still queued when a frame failed.
  int droppedFrames = 0;

  /// Each frame's result, in timestamp order. One subscription; pausing
  /// buffers, cancelling discards later results.
  Stream<R> get results => _results.stream;

  /// Checks [frame] and reserves its timestamp now; the frame then runs, or
  /// waits in the queue, or is dropped. Throws when a check fails.
  void submit(LiveFrame frame) {
    final (_, rotation, timestamp, _) = frame;
    _checks.liveStream(rotation, timestamp, listening: _listened);
    if (!_busy) {
      _start(frame);
    } else {
      if (_queued case final replaced?) _drop(replaced);
      _queued = frame;
    }
  }

  void _start(LiveFrame frame) {
    _busy = true;
    _run(frame).then(
      (result) {
        _results.add(result);
        // The listener gets this result before the queued frame starts: a
        // deferred frame is converted when it starts, on this isolate, and
        // starting it first would hold the result back by that conversion.
        scheduleMicrotask(_next);
      },
      onError: (Object error, StackTrace stack) {
        // Google's graph is unusable after an error, so the task fails with it
        // and the queued frame never runs.
        final failure = _checks.failure ??= error is TaskException
            ? error
            : TaskException('$error');
        if (_queued case final queued?) _drop(queued);
        _queued = null;
        _results.addError(failure, stack);
        unawaited(_results.close());
        _next();
      },
    );
  }

  void _next() {
    final queued = _queued;
    _queued = null;
    if (queued != null) {
      _start(queued);
    } else {
      _busy = false;
      _idle?.complete();
      _idle = null;
    }
  }

  void _drop(LiveFrame frame) {
    droppedFrames++;
    // The backend releases the browser frames it runs; this one it never sees.
    if (frame.$1.browserFrame case final browserFrame?) {
      releaseBrowserFrame(browserFrame);
    }
  }

  /// Runs the frame in flight and the queued one, as Google's close does,
  /// then closes [results]. The caller has stopped accepting frames first.
  Future<void> close() async {
    if (_busy) await (_idle ??= Completer<void>()).future;
    // A paused listener receives the end once it resumes; disposal does not
    // wait for it.
    unawaited(_results.close());
  }
}

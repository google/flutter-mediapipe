/// One stream's results: the stream a caller listens to, the clock that
/// stamps each window as Google does, and the one place a failure ends the
/// stream.
library;

import 'dart:async';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:meta/meta.dart';

import '../types.dart';
import 'checks.dart';
import 'google_tail_web.dart' if (dart.library.io) 'google_tail_io.dart';
import 'model_specs.dart';

/// Test hook: called with every timestamp Google's own stream delivers, before
/// the tail's sentinel is replaced, so that a test can show a result came from
/// Google's flush. Null outside tests.
@visibleForTesting
void Function(int timestampMilliseconds)? debugGoogleStreamTimestamp;

/// The results of one stream task, in window order.
final class AudioStreamResults {
  /// Results for a task whose [checks] the failure poisons.
  AudioStreamResults(this.checks);

  /// The task's checks, which hold its failure.
  final AudioStreamChecks checks;

  /// The model's audio input.
  AudioModelSpecs get specs => checks.specs;

  late final _controller = StreamController<AudioClassifierResult>(
    onListen: () => _listening = true,
  );
  var _listening = false;
  int? _firstTimestamp;
  var _windows = 0;

  /// One result per window, in order. One subscription; pausing buffers,
  /// cancelling discards later results.
  Stream<AudioClassifierResult> get stream => _controller.stream;

  /// Whether the caller has listened, which a block requires.
  bool get listening => _listening;

  /// Notes the timestamp of a block that holds samples. The first such
  /// block's timestamp is where the stream's first window starts, whatever
  /// later blocks say, as in Google's `AudioToTensorCalculator`.
  void blockSent(int timestampMilliseconds) =>
      _firstTimestamp ??= timestampMilliseconds;

  /// Where window [index] starts, in milliseconds: the first block's
  /// timestamp plus [index] steps of [AudioModelSpecs.stepMicroseconds].
  /// Google adds the steps in microseconds and divides the sum by 1000; the
  /// first timestamp is whole milliseconds, so adding it outside the division
  /// gives the same number and keeps browsers' arithmetic below 2^53.
  int windowTimestamp(int index) =>
      _firstTimestamp! + (index * specs.stepMicroseconds) ~/ 1000;

  /// Delivers a result of Google's own stream. A full window keeps Google's
  /// timestamp; the tail, which Google stamps with a sentinel instead of a
  /// time, gets the time its audio starts, as clips mode reports it.
  void addGoogle(AudioClassifierResult result) {
    final timestamp = result.timestampMilliseconds;
    debugGoogleStreamTimestamp?.call(timestamp);
    _deliver(
      timestamp == googleTailTimestamp
          ? AudioClassifierResult(
              classifications: result.classifications,
              timestampMilliseconds: windowTimestamp(_windows),
            )
          : result,
    );
  }

  /// Delivers window [index] of an emulated stream, stamped by the clock.
  void addWindow(int index, List<Classifications> classifications) => _deliver(
    AudioClassifierResult(
      classifications: classifications,
      timestampMilliseconds: windowTimestamp(index),
    ),
  );

  void _deliver(AudioClassifierResult result) {
    if (checks.failure != null || _controller.isClosed) return;
    _windows++;
    _controller.add(result);
  }

  /// Ends the stream with [error], once: the listener receives it as a
  /// [TaskException], the stream closes, and every later block rethrows it.
  void fail(Object error, [StackTrace? stack]) {
    if (checks.failure != null || _controller.isClosed) return;
    final failure = checks.failure = error is TaskException
        ? error
        : TaskException('$error', cause: error);
    _controller.addError(failure, stack);
    unawaited(_controller.close());
  }

  /// Closes the stream after the last result. A paused listener receives the
  /// end once it resumes; disposal does not wait for it.
  void close() {
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}

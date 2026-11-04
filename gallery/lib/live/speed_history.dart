import 'dart:math' as math;

import 'package:mediapipe_vision/mediapipe_vision.dart' show Delegate;

/// One frame's inference time, `seconds` into its delegate's run.
typedef SpeedSample = ({double seconds, double milliseconds});

/// Every frame's inference time since the camera started, one series per
/// delegate, for the Stats chart, with the frames dropped between them.
///
/// A page runs one delegate at a time. Each series' x is the time its own
/// delegate has been running, so after a switch the other line starts at zero
/// and the two overlay for comparison, without running both at once.
final class SpeedHistory {
  final _series = <Delegate, List<SpeedSample>>{};
  final _chartSeries = <Delegate, List<SpeedSample>>{};
  final _running = <Delegate, double>{};
  final _chartCount = <Delegate, int>{};

  /// Per delegate, the frames dropped since the sample before each sample.
  final _drops = <Delegate, List<int>>{};
  final _droppedSoFar = <Delegate, int>{};
  Delegate? _last;
  Duration? _lastAt;
  double _durationSeconds = 0;

  /// The chart averages within fixed quarter-second intervals. Once the
  /// next interval begins, earlier chart points never change.
  static const _chartInterval = 0.25;

  /// The longest pause that still counts as running, as between frames.
  /// A task restart or the still image mode takes longer and adds no time.
  static const _longestGap = 1.0;

  /// The samples of [delegate], oldest first.
  List<SpeedSample> operator [](Delegate delegate) =>
      _series[delegate] ?? const [];

  List<SpeedSample> chartSamples(Delegate delegate) =>
      _chartSeries[delegate] ?? const [];

  double get durationSeconds => _durationSeconds;

  /// The highest value actually drawn for [delegates].
  double chartPeak(Iterable<Delegate> delegates) {
    var peak = 0.0;
    for (final delegate in delegates) {
      for (final sample in chartSamples(delegate)) {
        if (sample.milliseconds > peak) peak = sample.milliseconds;
      }
    }
    return peak;
  }

  /// Samples recorded on every delegate, for repainting when it changes.
  int get length => _series.values.fold(0, (sum, list) => sum + list.length);

  /// Records a frame that took [milliseconds], processed at [at] on any clock
  /// that only moves forward, when the camera had dropped [dropped] frames
  /// since it started.
  void add(
    Delegate delegate,
    double milliseconds,
    Duration at, {
    int dropped = 0,
  }) {
    var seconds = _running[delegate] ?? 0;
    var continuous = false;
    if (_last == delegate && _lastAt != null) {
      final gap =
          (at - _lastAt!).inMicroseconds / Duration.microsecondsPerSecond;
      if (gap > 0 && gap <= _longestGap) {
        seconds += gap;
        continuous = true;
      }
    }
    _running[delegate] = seconds;
    // A new run counts its drops from its own first frame.
    final before = continuous ? _droppedSoFar[delegate] ?? dropped : dropped;
    (_drops[delegate] ??= []).add(math.max(0, dropped - before));
    _droppedSoFar[delegate] = dropped;
    (_series[delegate] ??= []).add((
      seconds: seconds,
      milliseconds: milliseconds,
    ));
    if (seconds > _durationSeconds) _durationSeconds = seconds;
    final chart = _chartSeries[delegate] ??= [];
    final bucket = (seconds / _chartInterval).floor();
    if (continuous &&
        chart.isNotEmpty &&
        (chart.last.seconds / _chartInterval).floor() == bucket) {
      final count = _chartCount[delegate]!;
      chart[chart.length - 1] = (
        seconds: bucket * _chartInterval,
        milliseconds:
            (chart.last.milliseconds * count + milliseconds) / (count + 1),
      );
      _chartCount[delegate] = count + 1;
    } else {
      chart.add((seconds: bucket * _chartInterval, milliseconds: milliseconds));
      _chartCount[delegate] = 1;
    }
    _last = delegate;
    _lastAt = at;
  }

  /// Forgets every frame, so each delegate's line starts again from zero.
  void clear() {
    _series.clear();
    _chartSeries.clear();
    _running.clear();
    _chartCount.clear();
    _drops.clear();
    _droppedSoFar.clear();
    _last = null;
    _lastAt = null;
    _durationSeconds = 0;
  }

  /// The mean inference time of [delegate]'s last [frames] frames, or null
  /// before its first.
  double? recent(Delegate delegate, {int frames = 30}) {
    final samples = this[delegate];
    if (samples.isEmpty) return null;
    final window = samples.length < frames
        ? samples
        : samples.sublist(samples.length - frames);
    return window.fold<double>(0, (sum, s) => sum + s.milliseconds) /
        window.length;
  }

  /// Frames dropped per second over [delegate]'s last [frames] frames, or
  /// null before it has two.
  double? droppedPerSecond(Delegate delegate, {int frames = 30}) {
    final samples = this[delegate];
    if (samples.length < 2) return null;
    final first = math.max(0, samples.length - frames);
    final span = samples.last.seconds - samples[first].seconds;
    if (span <= 0) return null;
    final dropped = _drops[delegate]!
        .skip(first + 1)
        .fold<int>(0, (sum, count) => sum + count);
    return dropped / span;
  }
}

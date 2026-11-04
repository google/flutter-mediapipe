import 'dart:collection';

typedef _Frame = ({double inference, int finishedMicroseconds});

/// The last [capacity] processed frames' timings, so the live readout follows
/// the current speed instead of an average still carrying the first, slower
/// frames.
class RecentFrameTimings {
  RecentFrameTimings({this.capacity = 300});

  final int capacity;
  final _frames = ListQueue<_Frame>();

  /// Frames in the window: [capacity] once that many have been processed.
  int get length => _frames.length;

  void clear() => _frames.clear();

  /// Records one frame; [finishedMicroseconds] is when it finished, on any
  /// clock that only moves forward.
  void add({required double inference, required int finishedMicroseconds}) {
    _frames.addLast((
      inference: inference,
      finishedMicroseconds: finishedMicroseconds,
    ));
    if (_frames.length > capacity) _frames.removeFirst();
  }

  double get inferenceMilliseconds => _frames.isEmpty
      ? 0
      : _frames.map((frame) => frame.inference).reduce((a, b) => a + b) /
            _frames.length;

  /// Frames finished per second across the window.
  double get framesPerSecond {
    if (_frames.length < 2) return 0;
    final span =
        _frames.last.finishedMicroseconds - _frames.first.finishedMicroseconds;
    return span <= 0 ? 0 : (_frames.length - 1) * 1000000 / span;
  }
}

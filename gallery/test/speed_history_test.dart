import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/speed_history.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

Duration _ms(int value) => Duration(milliseconds: value);

List<double> _seconds(SpeedHistory history, Delegate delegate) => [
  for (final sample in history[delegate]) sample.seconds,
];

void main() {
  test('each delegate is timed from its own start, so the lines overlay', () {
    final history = SpeedHistory()
      ..add(Delegate.gpu, 5.4, _ms(0))
      ..add(Delegate.gpu, 5.8, _ms(100))
      ..add(Delegate.gpu, 5.6, _ms(200))
      ..add(Delegate.cpu, 8.7, _ms(1400))
      ..add(Delegate.cpu, 8.3, _ms(1500));
    expect(_seconds(history, Delegate.gpu), [
      0,
      closeTo(.1, 1e-9),
      closeTo(.2, 1e-9),
    ]);
    expect(_seconds(history, Delegate.cpu), [0, closeTo(.1, 1e-9)]);
    expect(history[Delegate.cpu].last.milliseconds, 8.3);
    expect(history.length, 5);
  });

  test('switching back continues a delegate where it stopped', () {
    final history = SpeedHistory()
      ..add(Delegate.cpu, 9, _ms(0))
      ..add(Delegate.cpu, 9, _ms(500))
      ..add(Delegate.gpu, 6, _ms(2000))
      ..add(Delegate.cpu, 8, _ms(4000))
      ..add(Delegate.cpu, 8, _ms(4250));
    expect(_seconds(history, Delegate.cpu), [
      0,
      closeTo(.5, 1e-9),
      closeTo(.5, 1e-9),
      closeTo(.75, 1e-9),
    ]);
  });

  test('a pause of over a second adds no running time', () {
    final history = SpeedHistory()
      ..add(Delegate.gpu, 6, _ms(0))
      ..add(Delegate.gpu, 6, _ms(3000))
      ..add(Delegate.gpu, 6, _ms(3200));
    expect(_seconds(history, Delegate.gpu), [0, 0, closeTo(.2, 1e-9)]);
  });

  test('recent averages the latest frames of one delegate', () {
    final history = SpeedHistory();
    expect(history.recent(Delegate.cpu), isNull);
    for (var i = 0; i < 40; i++) {
      history.add(Delegate.cpu, i < 10 ? 100 : 8, _ms(i * 30));
    }
    expect(history.recent(Delegate.cpu), 8);
    expect(history.recent(Delegate.cpu, frames: 40), closeTo(31, 1e-9));
  });

  test('the vertical peak follows the values actually drawn', () {
    final history = SpeedHistory()
      ..add(Delegate.cpu, 20, _ms(0))
      ..add(Delegate.cpu, 10, _ms(100))
      ..add(Delegate.cpu, 8, _ms(300));
    final first = history.chartSamples(Delegate.cpu).first;
    expect(first.milliseconds, 15);
    expect(history.chartPeak([Delegate.cpu]), 15);

    for (var i = 4; i <= 400; i++) {
      history.add(Delegate.cpu, 5, _ms(i * 100));
    }
    expect(history.chartSamples(Delegate.cpu).first, first);
    expect(history.chartPeak([Delegate.cpu]), 15);
    expect(history.durationSeconds, greaterThan(30));
  });

  test('a resumed delegate never rewrites a point from before the pause', () {
    final history = SpeedHistory()
      ..add(Delegate.cpu, 20, _ms(0))
      ..add(Delegate.cpu, 10, _ms(100));
    final before = history.chartSamples(Delegate.cpu).first;
    history.add(Delegate.cpu, 5, _ms(3000));
    expect(history.chartSamples(Delegate.cpu).first, before);
    expect(history.chartSamples(Delegate.cpu).length, 2);
  });

  test('clear forgets every frame, and each line starts again from zero', () {
    final history = SpeedHistory()
      ..add(Delegate.gpu, 5, _ms(0))
      ..add(Delegate.gpu, 6, _ms(100))
      ..add(Delegate.cpu, 9, _ms(1000));
    history.clear();
    expect(history.length, 0);
    expect(history.durationSeconds, 0);
    expect(history.recent(Delegate.gpu), isNull);
    expect(history.chartSamples(Delegate.cpu), isEmpty);
    expect(history.chartPeak(Delegate.values), 0);

    // Even a frame right after the last one starts a fresh line.
    history
      ..add(Delegate.cpu, 8, _ms(1100))
      ..add(Delegate.cpu, 8, _ms(1200));
    expect(_seconds(history, Delegate.cpu), [0, closeTo(.1, 1e-9)]);
    expect(history[Delegate.gpu], isEmpty);
  });

  test('drops per second count from each run\'s first frame', () {
    final history = SpeedHistory()
      ..add(Delegate.cpu, 30, _ms(0), dropped: 0)
      ..add(Delegate.cpu, 30, _ms(500), dropped: 4)
      ..add(Delegate.cpu, 30, _ms(1000), dropped: 10);
    expect(history.droppedPerSecond(Delegate.cpu), closeTo(10, 1e-9));
    expect(
      history.droppedPerSecond(Delegate.cpu, frames: 2),
      closeTo(12, 1e-9),
    );
    // A restart (the task's count starts again) after a pause adds no drops
    // for its first frame, whatever the count it starts from.
    history
      ..add(Delegate.cpu, 30, _ms(5000), dropped: 2)
      ..add(Delegate.cpu, 30, _ms(5500), dropped: 3);
    expect(history.droppedPerSecond(Delegate.cpu, frames: 2), closeTo(2, 1e-9));
    expect(history.droppedPerSecond(Delegate.gpu), isNull);
    history.clear();
    expect(history.droppedPerSecond(Delegate.cpu), isNull);
  });
}

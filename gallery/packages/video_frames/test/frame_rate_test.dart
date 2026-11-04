import 'package:flutter_test/flutter_test.dart';
import 'package:video_frames/src/frame_rate.dart';

/// Frame callbacks at [rate] for frames [shown] of the file, numbered from 0,
/// each with the count of frames presented so far.
List<(double, int)> callbacks(double rate, List<int> shown) => [
  for (final (index, frame) in shown.indexed) (frame / rate, index + 1),
];

/// The frames a reader stepping [frameSeconds] at a time visits in a file of
/// [seconds]: one per slot whose middle lies before the end.
int slots(double frameSeconds, double seconds) =>
    (seconds / frameSeconds - 0.5).ceil();

void main() {
  test('a steady 30 fps playback measures 30 fps', () {
    final seconds = frameSecondsFrom(
      callbacks(30, [for (var i = 0; i < 12; i++) i]),
    );
    expect(seconds, 1 / 30);
    expect(slots(seconds!, 3), 90);
  });

  test('a frame dropped without being presented still measures 30 fps', () {
    // The CI failure: frame 6 was never presented, so 11 presented frames
    // covered 12 frames of media time and the average read 27.5 fps, which
    // stepped through the 90 frame sample in 82 or 83 seeks.
    final shown = [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12];
    final seconds = frameSecondsFrom(callbacks(30, shown));
    expect(seconds, 1 / 30);
    expect(slots(seconds!, 3), 90);
  });

  test('two dropped frames still measure 30 fps', () {
    final shown = [0, 1, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13];
    expect(frameSecondsFrom(callbacks(30, shown)), 1 / 30);
  });

  test('frames presented between callbacks count as presented', () {
    // A callback that comes late reports every frame shown since the last.
    final presented = [
      (0 / 30, 1),
      (1 / 30, 2),
      (3 / 30, 4),
      (4 / 30, 5),
      (5 / 30, 6),
      (7 / 30, 8),
      (8 / 30, 9),
    ];
    expect(frameSecondsFrom(presented), 1 / 30);
  });

  test('media time jitter keeps the common rate', () {
    final jitter = [0.0, 0.004, -0.003, 0.002, -0.004, 0.003, 0.0, -0.002];
    final presented = [
      for (final (index, offset) in jitter.indexed)
        (index / 30 + offset, index + 1),
    ];
    expect(frameSecondsFrom(presented), 1 / 30);
  });

  test('NTSC rates round to theirs', () {
    expect(
      frameSecondsFrom(
        callbacks(30000 / 1001, [for (var i = 0; i < 12; i++) i]),
      ),
      1001 / 30000,
    );
  });

  test('an uncommon rate is kept as measured', () {
    final seconds = frameSecondsFrom(
      callbacks(27.5, [for (var i = 0; i < 12; i++) i]),
    );
    expect(seconds, closeTo(1 / 27.5, 1e-9));
  });

  test('too few callbacks, or none advancing, tell nothing', () {
    expect(frameSecondsFrom([]), isNull);
    expect(frameSecondsFrom([(0, 1)]), isNull);
    expect(frameSecondsFrom([(0, 1), (0, 1), (0, 1)]), isNull);
  });
}

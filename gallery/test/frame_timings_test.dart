import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/frame_timings.dart';

void main() {
  test('readout uses the latest 300 frames after the window fills', () {
    final timings = RecentFrameTimings();

    timings.add(inference: 1000, finishedMicroseconds: 0);
    for (var frame = 1; frame <= 300; frame++) {
      timings.add(inference: 10, finishedMicroseconds: frame * 40000);
    }

    expect(timings.length, 300);
    expect(timings.inferenceMilliseconds, 10);
    expect(timings.framesPerSecond, 25);

    timings.clear();
    expect(timings.length, 0);
    expect(timings.framesPerSecond, 0);
  });
}

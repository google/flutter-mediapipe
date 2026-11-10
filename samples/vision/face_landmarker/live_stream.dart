import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef CameraFrame = ({Uint8List rgba, int width, int height});

Future<void> countFacesLive(Stream<CameraFrame> cameraFrames) async {
  final task = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      runningMode: RunningMode.liveStream,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = task.results.listen((result) {
    print('${result.timestampMilliseconds}: ${result.faceLandmarks.length}');
  });
  final clock = Stopwatch()..start();
  var last = -1;
  try {
    await for (final frame in cameraFrames) {
      // Stamp each frame when it arrives, but never twice with one value.
      final now = clock.elapsedMilliseconds;
      last = now > last ? now : last + 1;
      task.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: last,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await task.dispose();
    await results.cancel();
  }
}

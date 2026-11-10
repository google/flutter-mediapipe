import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> detectObjectsLive(Stream<Frame> frames) async {
  final detector = await ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      runningMode: RunningMode.liveStream,
      maxResults: 5,
      scoreThreshold: 0.4,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = detector.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final detection in result.detections) {
      final label = detection.categories.first;
      final box = detection.boundingBox;
      print('$ms ms: ${label.categoryName} at ${box.left},${box.top}');
    }
  });
  try {
    await for (final frame in frames) {
      detector.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await detector.dispose();
    await results.cancel();
    print('${detector.droppedFrames} frames dropped');
  }
}

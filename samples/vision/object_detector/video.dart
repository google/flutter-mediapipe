import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> detectObjectsInVideo(Stream<Frame> frames) async {
  final detector = await ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      runningMode: RunningMode.video,
      maxResults: 5,
      scoreThreshold: 0.4,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await detector.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final detection in result.detections) {
        final label = detection.categories.first;
        final box = detection.boundingBox;
        print('$ms ms: ${label.categoryName} at ${box.left},${box.top}');
      }
    }
  } finally {
    await detector.dispose();
  }
}

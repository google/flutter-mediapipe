import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> recognizeGesturesInVideo(Stream<Frame> frames) async {
  final recognizer = await GestureRecognizer.create(
    GestureRecognizerOptions(
      model: VisionModels.gestureRecognizer,
      runningMode: RunningMode.video,
      numHands: 2,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await recognizer.recognizeForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final gestures in result.gestures) {
        final top = gestures.first;
        print('$ms ms: ${top.categoryName} (${top.score.toStringAsFixed(2)})');
      }
    }
  } finally {
    await recognizer.dispose();
  }
}

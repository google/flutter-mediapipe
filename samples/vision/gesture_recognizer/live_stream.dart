import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> recognizeGesturesLive(Stream<Frame> frames) async {
  final recognizer = await GestureRecognizer.create(
    GestureRecognizerOptions(
      model: VisionModels.gestureRecognizer,
      runningMode: RunningMode.liveStream,
      numHands: 2,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = recognizer.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final gestures in result.gestures) {
      final top = gestures.first;
      print('$ms ms: ${top.categoryName} (${top.score.toStringAsFixed(2)})');
    }
  });
  try {
    await for (final frame in frames) {
      recognizer.recognizeAsync(
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
    await recognizer.dispose();
    await results.cancel();
    print('${recognizer.droppedFrames} frames dropped');
  }
}

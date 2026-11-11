import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> classifyFramesLive(Stream<Frame> frames) async {
  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(
      model: VisionModels.imageClassifier,
      runningMode: RunningMode.liveStream,
      maxResults: 3,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = classifier.results.listen((result) {
    final ms = result.timestampMilliseconds;
    final top = result.classifications.first.categories.map(
      (category) =>
          '${category.categoryName} ${category.score.toStringAsFixed(2)}',
    );
    print('$ms ms: ${top.join(', ')}');
  });
  try {
    await for (final frame in frames) {
      classifier.classifyAsync(
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
    await classifier.dispose();
    await results.cancel();
    print('${classifier.droppedFrames} frames dropped');
  }
}

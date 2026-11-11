import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> classifyFramesInVideo(Stream<Frame> frames) async {
  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(
      model: VisionModels.imageClassifier,
      runningMode: RunningMode.video,
      maxResults: 3,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await classifier.classifyForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      final top = result.classifications.first.categories.map(
        (category) =>
            '${category.categoryName} ${category.score.toStringAsFixed(2)}',
      );
      print('$ms ms: ${top.join(', ')}');
    }
  } finally {
    await classifier.dispose();
  }
}

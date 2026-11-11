import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> compareFramesInVideo(Stream<Frame> frames) async {
  final embedder = await ImageEmbedder.create(
    ImageEmbedderOptions(
      model: VisionModels.imageEmbedder,
      runningMode: RunningMode.video,
      l2Normalize: true,
    ),
  );
  Embedding? previous;
  try {
    await for (final frame in frames) {
      final result = await embedder.embedForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      final embedding = result.embeddings.first;
      if (previous case final last?) {
        final similarity = ImageEmbedder.cosineSimilarity(last, embedding);
        print('$ms ms: ${similarity.toStringAsFixed(3)} like the frame before');
      }
      previous = embedding;
    }
  } finally {
    await embedder.dispose();
  }
}

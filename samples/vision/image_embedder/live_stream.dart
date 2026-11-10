import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> compareFramesLive(Stream<Frame> frames) async {
  final embedder = await ImageEmbedder.create(
    ImageEmbedderOptions(
      model: VisionModels.imageEmbedder,
      runningMode: RunningMode.liveStream,
      l2Normalize: true,
    ),
  );
  Embedding? previous;
  // Listen before the first frame, as Google requires a result listener.
  final results = embedder.results.listen((result) {
    final ms = result.timestampMilliseconds;
    final embedding = result.embeddings.first;
    if (previous case final last?) {
      final similarity = ImageEmbedder.cosineSimilarity(last, embedding);
      print('$ms ms: ${similarity.toStringAsFixed(3)} like the frame before');
    }
    previous = embedding;
  });
  try {
    await for (final frame in frames) {
      embedder.embedAsync(
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
    await embedder.dispose();
    await results.cancel();
    print('${embedder.droppedFrames} frames dropped');
  }
}

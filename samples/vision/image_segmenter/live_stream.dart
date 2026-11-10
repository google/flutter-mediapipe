import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> segmentSceneLive(Stream<Frame> frames) async {
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(
      model: VisionModels.imageSegmenter,
      runningMode: RunningMode.liveStream,
      outputCategoryMask: true,
      outputConfidenceMasks: false,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = segmenter.results.listen((result) {
    final ms = result.timestampMilliseconds;
    final mask = result.categoryMask!;
    final center =
        mask.categories[mask.height ~/ 2 * mask.width + mask.width ~/ 2];
    // Labels come from the model's metadata, which may have none.
    final label = center < result.labels.length
        ? result.labels[center]
        : 'category $center';
    print('$ms ms: the center pixel is $label');
  });
  try {
    await for (final frame in frames) {
      segmenter.segmentAsync(
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
    await segmenter.dispose();
    await results.cancel();
    print('${segmenter.droppedFrames} frames dropped');
  }
}

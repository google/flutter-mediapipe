import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> segmentSceneInVideo(Stream<Frame> frames) async {
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(
      model: VisionModels.imageSegmenter,
      runningMode: RunningMode.video,
      outputCategoryMask: true,
      outputConfidenceMasks: false,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await segmenter.segmentForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      final mask = result.categoryMask!;
      final center =
          mask.categories[mask.height ~/ 2 * mask.width + mask.width ~/ 2];
      // Labels come from the model's metadata, which may have none.
      final label = center < result.labels.length
          ? result.labels[center]
          : 'category $center';
      print('$ms ms: the center pixel is $label');
    }
  } finally {
    await segmenter.dispose();
  }
}

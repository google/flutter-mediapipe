import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> segmentScene(VisionImage image) async {
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(
      model: VisionModels.imageSegmenter,
      outputCategoryMask: true,
      outputConfidenceMasks: false,
    ),
  );
  try {
    final result = await segmenter.segment(image);
    final mask = result.categoryMask!;
    final center =
        mask.categories[mask.height ~/ 2 * mask.width + mask.width ~/ 2];
    // Labels come from the model's metadata, which may have none.
    final label = center < result.labels.length
        ? result.labels[center]
        : 'category $center';
    print('The center pixel is $label');
  } finally {
    await segmenter.dispose();
  }
}

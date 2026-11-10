import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> measureCategories(VisionImage image) async {
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(model: VisionModels.imageSegmenter),
  );
  try {
    final result = await segmenter.segment(image);
    for (final (index, mask) in result.confidenceMasks!.indexed) {
      final covered = mask.confidence.where((c) => c > 0.5).length;
      if (covered == 0) continue;
      final share = 100 * covered / (mask.width * mask.height);
      // Labels come from the model's metadata, which may have none.
      final label = index < result.labels.length
          ? result.labels[index]
          : 'category $index';
      print('$label: ${share.toStringAsFixed(1)}% of the image');
    }
  } finally {
    await segmenter.dispose();
  }
}

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> measurePeople(VisionImage image) async {
  final landmarker = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      model: VisionModels.poseLandmarker,
      numPoses: 2,
      outputSegmentationMasks: true,
    ),
  );
  try {
    final result = await landmarker.detect(image);
    for (final (index, mask) in result.segmentationMasks!.indexed) {
      final covered = mask.confidence.where((c) => c > 0.5).length;
      final share = 100 * covered / (mask.width * mask.height);
      print('Person $index covers ${share.toStringAsFixed(1)}% of the image');
    }
  } finally {
    await landmarker.dispose();
  }
}

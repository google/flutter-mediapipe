import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> describePerson(VisionImage image) async {
  final landmarker = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      model: VisionModels.holisticLandmarker,
      outputPoseSegmentationMask: true,
      outputFaceBlendshapes: true,
    ),
  );
  try {
    final result = await landmarker.detect(image);
    if (result.poseSegmentationMask case final mask?) {
      final covered = mask.confidence.where((c) => c > 0.5).length;
      final share = 100 * covered / (mask.width * mask.height);
      print('The person covers ${share.toStringAsFixed(1)}% of the image');
    }
    if (result.faceBlendshapes case final blendshapes?) {
      final strongest = blendshapes.reduce((a, b) => a.score > b.score ? a : b);
      print('Strongest expression: ${strongest.categoryName}');
    }
  } finally {
    await landmarker.dispose();
  }
}

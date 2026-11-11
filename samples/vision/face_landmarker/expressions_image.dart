import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> readExpression(VisionImage image) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      outputFaceBlendshapes: true,
    ),
  );
  try {
    final result = await landmarker.detect(image);
    if (result.faceBlendshapes.isEmpty) return;
    final strongest = [...result.faceBlendshapes.first]
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final shape in strongest.take(3)) {
      print('${shape.categoryName}: ${shape.score.toStringAsFixed(2)}');
    }
  } finally {
    await landmarker.dispose();
  }
}

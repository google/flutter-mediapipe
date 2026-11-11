import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> printHeadTransforms(VisionImage image) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      outputFacialTransformationMatrixes: true,
    ),
  );
  try {
    final result = await landmarker.detect(image);
    for (final matrix in result.facialTransformationMatrixes) {
      for (var row = 0; row < matrix.rows; row++) {
        final values = [
          for (var column = 0; column < matrix.columns; column++)
            matrix.at(row, column).toStringAsFixed(2),
        ];
        print(values.join(' '));
      }
    }
  } finally {
    await landmarker.dispose();
  }
}

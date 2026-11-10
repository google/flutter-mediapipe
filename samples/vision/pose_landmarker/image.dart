import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> findPoses(VisionImage image) async {
  final landmarker = await PoseLandmarker.create(
    PoseLandmarkerOptions(model: VisionModels.poseLandmarker),
  );
  try {
    final result = await landmarker.detect(image);
    for (final pose in result.poseLandmarks) {
      final nose = pose.first;
      print('Nose at ${nose.x}, ${nose.y}, visibility ${nose.visibility}');
    }
  } finally {
    await landmarker.dispose();
  }
}

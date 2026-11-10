import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> findHands(VisionImage image) async {
  final landmarker = await HandLandmarker.create(
    HandLandmarkerOptions(model: VisionModels.handLandmarker, numHands: 2),
  );
  try {
    final result = await landmarker.detect(image);
    for (var i = 0; i < result.handLandmarks.length; i++) {
      final side = result.handedness[i].first.categoryName;
      final wrist = result.handLandmarks[i].first;
      print('$side hand, wrist at ${wrist.x}, ${wrist.y}');
    }
  } finally {
    await landmarker.dispose();
  }
}

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> trackPerson(VisionImage image) async {
  final landmarker = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(model: VisionModels.holisticLandmarker),
  );
  try {
    final result = await landmarker.detect(image);
    print('Face: ${result.faceLandmarks.length} landmarks');
    print('Pose: ${result.poseLandmarks.length} landmarks');
    print('Left hand: ${result.leftHandLandmarks.length} landmarks');
    print('Right hand: ${result.rightHandLandmarks.length} landmarks');
  } finally {
    await landmarker.dispose();
  }
}

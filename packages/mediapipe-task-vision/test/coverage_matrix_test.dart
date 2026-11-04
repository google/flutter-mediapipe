import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:test/test.dart';

import '../../mediapipe-core/test/support/coverage_matrix.dart';

// tool/coverage/matrix.json against the vision claims, read with every
// platform adapter registered and the official macOS and iOS runtimes
// selected, the configuration CI tests.
final _claims = <String, TaskCapabilities Function(TaskPlatform)>{
  'face_detector': faceDetectorCapabilitiesForPlatform,
  'face_landmarker': faceLandmarkerCapabilitiesForPlatform,
  'gesture_recognizer': gestureRecognizerCapabilitiesForPlatform,
  'hand_landmarker': handLandmarkerCapabilitiesForPlatform,
  'holistic_landmarker': holisticLandmarkerCapabilitiesForPlatform,
  'image_classifier': imageClassifierCapabilitiesForPlatform,
  'image_embedder': imageEmbedderCapabilitiesForPlatform,
  'image_segmenter': imageSegmenterCapabilitiesForPlatform,
  'interactive_segmenter': interactiveSegmenterCapabilitiesForPlatform,
  'object_detector': objectDetectorCapabilitiesForPlatform,
  'pose_landmarker': poseLandmarkerCapabilitiesForPlatform,
};

Never _unused(Object? _) => throw UnimplementedError();

void main() {
  setUpAll(() {
    faceLandmarkerBackendFactory = _unused;
    faceDetectorBackendFactory = _unused;
    handLandmarkerBackendFactory = _unused;
    poseLandmarkerBackendFactory = _unused;
    gestureRecognizerBackendFactory = _unused;
    holisticLandmarkerBackendFactory = _unused;
    objectDetectorBackendFactory = _unused;
    imageClassifierBackendFactory = _unused;
    imageEmbedderBackendFactory = _unused;
    imageSegmenterBackendFactory = _unused;
    interactiveSegmenterBackendFactory = _unused;
  });

  test('coverage matrix agrees with the vision capability claims', () {
    expect(coverageMatrixProblems(_claims), isEmpty);
  });
}

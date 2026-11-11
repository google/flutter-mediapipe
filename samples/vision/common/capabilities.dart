import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> reportVisionSupport() async {
  final queries = <String, Future<TaskCapabilities> Function()>{
    'Face Detector': queryFaceDetectorCapabilities,
    'Face Landmarker': queryFaceLandmarkerCapabilities,
    'Hand Landmarker': queryHandLandmarkerCapabilities,
    'Gesture Recognizer': queryGestureRecognizerCapabilities,
    'Pose Landmarker': queryPoseLandmarkerCapabilities,
    'Holistic Landmarker': queryHolisticLandmarkerCapabilities,
    'Object Detector': queryObjectDetectorCapabilities,
    'Image Classifier': queryImageClassifierCapabilities,
    'Image Embedder': queryImageEmbedderCapabilities,
    'Image Segmenter': queryImageSegmenterCapabilities,
    'Interactive Segmenter': queryInteractiveSegmenterCapabilities,
  };
  for (final MapEntry(key: task, value: query) in queries.entries) {
    final support = await query();
    final delegates = support.supportedDelegates.map((d) => d.name);
    print('$task: ${delegates.isEmpty ? 'unavailable' : delegates.join(', ')}');
    for (final MapEntry(key: delegate, value: reason)
        in support.unavailableReasons.entries) {
      print('  no ${delegate.name}: $reason');
    }
  }
}

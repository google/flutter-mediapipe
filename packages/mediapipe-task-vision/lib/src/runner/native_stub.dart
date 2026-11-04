/// Browsers have no native runtime: every task runs through the registered
/// browser plugin, so reaching these means it did not register.
library;

import 'package:mediapipe_core/platform_interface.dart'
    show pluginNotRegistered;

import '../types/options.dart';
import '../types/results.dart';
import '../types/vision_types.dart';
import '../vision_task_backend.dart';
import 'native_interface.dart';

Never _unavailable() => throw pluginNotRegistered('mediapipe_vision');

/// Opens Google's native task on a worker; browsers have none.
Future<NativeTaskRunner<R>> openNativeTask<R, O extends VisionTaskOptions>(
  O options,
  NativeVisionTask<R> Function(O) create,
  String name,
) async => _unavailable();

/// Opens Google's native stateful segmenter; browsers have none.
Future<InteractiveSegmenterBackend> openNativeInteractiveSegmenter(
  InteractiveSegmenterOptions options,
) async => _unavailable();

/// The native Face Detector; browsers have none.
NativeVisionTask<FaceDetectorResult> nativeFaceDetector(
  FaceDetectorOptions options,
) => _unavailable();

/// The native Face Landmarker; browsers have none.
NativeVisionTask<FaceLandmarkerResult> nativeFaceLandmarker(
  FaceLandmarkerOptions options,
) => _unavailable();

/// The native Hand Landmarker; browsers have none.
NativeVisionTask<HandLandmarkerResult> nativeHandLandmarker(
  HandLandmarkerOptions options,
) => _unavailable();

/// The native Gesture Recognizer; browsers have none.
NativeVisionTask<GestureRecognizerResult> nativeGestureRecognizer(
  GestureRecognizerOptions options,
) => _unavailable();

/// The native Pose Landmarker; browsers have none.
NativeVisionTask<PoseLandmarkerResult> nativePoseLandmarker(
  PoseLandmarkerOptions options,
) => _unavailable();

/// The native Holistic Landmarker; browsers have none.
NativeVisionTask<HolisticLandmarkerResult> nativeHolisticLandmarker(
  HolisticLandmarkerOptions options,
) => _unavailable();

/// The native Object Detector; browsers have none.
NativeVisionTask<ObjectDetectorResult> nativeObjectDetector(
  ObjectDetectorOptions options,
) => _unavailable();

/// The native Image Classifier; browsers have none.
NativeVisionTask<ImageClassifierResult> nativeImageClassifier(
  ImageClassifierOptions options,
) => _unavailable();

/// The native Image Embedder; browsers have none.
NativeVisionTask<ImageEmbedderResult> nativeImageEmbedder(
  ImageEmbedderOptions options,
) => _unavailable();

/// The native Image Segmenter; browsers have none.
NativeVisionTask<ImageSegmenterResult> nativeImageSegmenter(
  ImageSegmenterOptions options,
) => _unavailable();

/// Pose masks on desktop GPUs are refused by the native runtime; browsers
/// draw them on WebGL, so nothing to check here.
void validatePoseMasks(PoseLandmarkerOptions options) {}

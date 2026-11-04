/// Google's native runtime, where the compiler has `dart:io`: the task
/// classes reach it through `runner/native_tasks.dart`.
library;

import 'dart:io';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart' show requireDelegate;

import '../capabilities.dart';
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import '../types/vision_types.dart';
import '../vision_task_backend.dart';
import 'native_face_detector.dart';
import 'native_face_landmarker.dart';
import 'native_gesture_recognizer.dart';
import 'native_hand_landmarker.dart';
import 'native_holistic_landmarker.dart';
import 'native_image_classifier.dart';
import 'native_image_embedder.dart';
import 'native_image_segmenter.dart';
import 'native_interactive_segmenter_runner.dart';
import 'native_object_detector.dart';
import 'native_pose_landmarker.dart';
import 'vision_task_worker.dart';

/// Opens Google's native task on a worker isolate.
Future<NativeTaskRunner<R>> openNativeTask<R, O extends VisionTaskOptions>(
  O options,
  NativeVisionTask<R> Function(O) create,
  String name,
) => VisionTaskWorker.create(options, create, name);

/// Opens Google's stateful segmenter on a worker isolate, after the
/// capability query admits the delegate here.
Future<InteractiveSegmenterBackend> openNativeInteractiveSegmenter(
  InteractiveSegmenterOptions options,
) async {
  requireDelegate(
    await queryInteractiveSegmenterCapabilities(),
    options.delegate,
  );
  return NativeInteractiveSegmenterRunner.open(options);
}

/// The native Face Detector.
NativeVisionTask<FaceDetectorResult> nativeFaceDetector(
  FaceDetectorOptions options,
) => NativeFaceDetector(options);

/// The native Face Landmarker.
NativeVisionTask<FaceLandmarkerResult> nativeFaceLandmarker(
  FaceLandmarkerOptions options,
) => NativeFaceLandmarker(options);

/// The native Hand Landmarker.
NativeVisionTask<HandLandmarkerResult> nativeHandLandmarker(
  HandLandmarkerOptions options,
) => NativeHandLandmarker(options);

/// The native Gesture Recognizer.
NativeVisionTask<GestureRecognizerResult> nativeGestureRecognizer(
  GestureRecognizerOptions options,
) => NativeGestureRecognizer(options);

/// The native Pose Landmarker.
NativeVisionTask<PoseLandmarkerResult> nativePoseLandmarker(
  PoseLandmarkerOptions options,
) => NativePoseLandmarker(options);

/// The native Holistic Landmarker.
NativeVisionTask<HolisticLandmarkerResult> nativeHolisticLandmarker(
  HolisticLandmarkerOptions options,
) => NativeHolisticLandmarker(options);

/// The native Object Detector.
NativeVisionTask<ObjectDetectorResult> nativeObjectDetector(
  ObjectDetectorOptions options,
) => NativeObjectDetector(options);

/// The native Image Classifier.
NativeVisionTask<ImageClassifierResult> nativeImageClassifier(
  ImageClassifierOptions options,
) => NativeImageClassifier(options);

/// The native Image Embedder.
NativeVisionTask<ImageEmbedderResult> nativeImageEmbedder(
  ImageEmbedderOptions options,
) => NativeImageEmbedder(options);

/// The native Image Segmenter.
NativeVisionTask<ImageSegmenterResult> nativeImageSegmenter(
  ImageSegmenterOptions options,
) => NativeImageSegmenter(options);

/// Refuses pose masks on the desktop GPUs where Google's runtime cannot
/// produce them, with the reason (upstream-issues.md UP-028 and UP-030).
void validatePoseMasks(PoseLandmarkerOptions options) {
  if ((Platform.isMacOS || Platform.isLinux) &&
      options.delegate == Delegate.gpu &&
      options.outputSegmentationMasks) {
    // Metal fails on the first frame; OpenGL ES returns 8-bit RGBA images
    // where the API promises float confidences.
    throw UnsupportedError(
      Platform.isMacOS
          ? 'Google\'s macOS runtime cannot initialize the pose '
                'segmentation mask upsampler on Metal (upstream-issues.md '
                'UP-028). Request masks on the CPU, or landmarks alone on '
                'the GPU.'
          : 'Google\'s Linux runtime returns pose masks on OpenGL ES as '
                '8-bit RGBA images, not float confidences (upstream-issues.md '
                'UP-030). Request masks on the CPU, or landmarks alone on the '
                'GPU.',
    );
  }
}

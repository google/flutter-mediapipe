/// Where the web plugin plugs Google's browser runtime into the task
/// classes. Applications use the task classes.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

import 'types/options.dart';
import 'types/results.dart';
import 'types/strokes.dart';
import 'types/vision_types.dart';

/// A serialized, asynchronous adapter to one task of Google's browser
/// runtime, on a worker.
abstract interface class VisionTaskBackend<R> {
  /// Completes with copied results; requests and disposal keep their
  /// submission order. Only the tasks that accept a region of interest
  /// receive [regionOfInterest]. A browser frame arrives as
  /// `image.browserFrame`, which the backend releases after inference.
  Future<R> detect(
    VisionImage image,
    int rotationDegrees,
    int? timestampMilliseconds, {
    VisionRegionOfInterest? regionOfInterest,
  });

  /// Finishes queued requests and releases the SDK task on its own thread.
  Future<void> dispose();
}

/// A backend that can draw its results into a browser canvas on its worker.
abstract interface class VisionTaskOverlayBackend {
  /// Transfers a browser canvas to the task's worker for drawing.
  Future<void> attachOverlay(Object canvas);

  /// Stops drawing; the transferred canvas stays blank afterwards.
  Future<void> detachOverlay();

  /// Chooses what the worker draws and how the preview is transformed.
  void setOverlayOptions({
    required bool connections,
    required bool points,
    required bool mirrored,
    required double scale,
  });

  /// False when canvas transfer is unsupported or worker drawing failed.
  bool get overlayActive;
}

/// Creates a task's backend from its options. Installed by a platform plugin
/// before the first task is created; null where the package runs Google's
/// native runtime itself.
typedef VisionBackendFactory<R, O> =
    Future<VisionTaskBackend<R>> Function(O options);

/// Installed by a platform plugin before the first FaceDetector is created.
VisionBackendFactory<FaceDetectorResult, FaceDetectorOptions>?
faceDetectorBackendFactory;

/// Installed by a platform plugin before the first FaceLandmarker is created.
VisionBackendFactory<FaceLandmarkerResult, FaceLandmarkerOptions>?
faceLandmarkerBackendFactory;

/// Installed by a platform plugin before the first HandLandmarker is created.
VisionBackendFactory<HandLandmarkerResult, HandLandmarkerOptions>?
handLandmarkerBackendFactory;

/// Installed by a platform plugin before the first GestureRecognizer is
/// created.
VisionBackendFactory<GestureRecognizerResult, GestureRecognizerOptions>?
gestureRecognizerBackendFactory;

/// Installed by a platform plugin before the first PoseLandmarker is created.
VisionBackendFactory<PoseLandmarkerResult, PoseLandmarkerOptions>?
poseLandmarkerBackendFactory;

/// Installed by a platform plugin before the first HolisticLandmarker is
/// created.
VisionBackendFactory<HolisticLandmarkerResult, HolisticLandmarkerOptions>?
holisticLandmarkerBackendFactory;

/// Installed by a platform plugin before the first ObjectDetector is created.
VisionBackendFactory<ObjectDetectorResult, ObjectDetectorOptions>?
objectDetectorBackendFactory;

/// Installed by a platform plugin before the first ImageClassifier is created.
VisionBackendFactory<ImageClassifierResult, ImageClassifierOptions>?
imageClassifierBackendFactory;

/// Installed by a platform plugin before the first ImageEmbedder is created.
VisionBackendFactory<ImageEmbedderResult, ImageEmbedderOptions>?
imageEmbedderBackendFactory;

/// Installed by a platform plugin before the first ImageSegmenter is created.
VisionBackendFactory<ImageSegmenterResult, ImageSegmenterOptions>?
imageSegmenterBackendFactory;

/// One stateful Interactive Segmenter session on an official platform SDK:
/// an image, then complete stroke histories, in submission order.
abstract interface class InteractiveSegmenterBackend {
  /// Replaces the image and resets the stroke session.
  Future<void> setImage(VisionImage image);

  /// Segments with the full, nonempty stroke history.
  Future<ConfidenceMask> segment(List<Stroke> strokes);

  /// Finishes queued requests and releases the SDK task.
  Future<void> dispose();
}

/// Installed by a platform plugin before the first InteractiveSegmenter is
/// created.
Future<InteractiveSegmenterBackend> Function(InteractiveSegmenterOptions)?
interactiveSegmenterBackendFactory;

/// The overlay backend behind a task, when its platform has one. Task classes
/// register theirs when they are created; `BrowserOverlay` looks it up.
final overlayBackends = Expando<VisionTaskOverlayBackend>('overlay backends');

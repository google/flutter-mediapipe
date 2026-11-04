/// The options of every vision task: Google's names and defaults, validated
/// the same way on every platform.
library;

import 'package:mediapipe_core/platform_interface.dart'
    show ClassifierSettings, checkClassifierSettings, checkLabel;

import 'vision_types.dart';

/// Options for the official Face Detector.
final class FaceDetectorOptions extends VisionTaskOptions {
  /// Thresholds match Google's defaults.
  FaceDetectorOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.minDetectionConfidence = 0.5,
    this.minSuppressionThreshold = 0.3,
  }) {
    checkConfidence(minDetectionConfidence, 'minDetectionConfidence');
    checkConfidence(minSuppressionThreshold, 'minSuppressionThreshold');
  }

  /// Minimum score for a detection to be returned.
  final double minDetectionConfidence;

  /// Intersection threshold of Google's non-maximum suppression.
  final double minSuppressionThreshold;
}

/// Options for the official Face Landmarker.
final class FaceLandmarkerOptions extends VisionTaskOptions {
  /// Defaults match Google's.
  FaceLandmarkerOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.numFaces = 1,
    this.minFaceDetectionConfidence = 0.5,
    this.minFacePresenceConfidence = 0.5,
    this.minTrackingConfidence = 0.5,
    this.outputFaceBlendshapes = false,
    this.outputFacialTransformationMatrixes = false,
  }) {
    checkCount(numFaces, 'numFaces');
    checkConfidence(minFaceDetectionConfidence, 'minFaceDetectionConfidence');
    checkConfidence(minFacePresenceConfidence, 'minFacePresenceConfidence');
    checkConfidence(minTrackingConfidence, 'minTrackingConfidence');
  }

  /// Maximum number of faces. Google's video smoothing applies only at 1.
  final int numFaces;

  /// Minimum face detection confidence.
  final double minFaceDetectionConfidence;

  /// Minimum face presence confidence.
  final double minFacePresenceConfidence;

  /// Minimum face tracking confidence.
  final double minTrackingConfidence;

  /// Include the model's 52 expression scores for each face.
  final bool outputFaceBlendshapes;

  /// Include the canonical-face-to-detected-face transform for each face.
  final bool outputFacialTransformationMatrixes;
}

/// Detection and tracking settings shared by the hand tasks.
abstract base class HandTrackingOptions extends VisionTaskOptions {
  /// Defaults match Google's Hand Landmarker and Gesture Recognizer.
  HandTrackingOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.numHands = 1,
    this.minHandDetectionConfidence = 0.5,
    this.minHandPresenceConfidence = 0.5,
    this.minTrackingConfidence = 0.5,
  }) {
    checkCount(numHands, 'numHands');
    checkConfidence(minHandDetectionConfidence, 'minHandDetectionConfidence');
    checkConfidence(minHandPresenceConfidence, 'minHandPresenceConfidence');
    checkConfidence(minTrackingConfidence, 'minTrackingConfidence');
  }

  /// Maximum number of detected hands.
  final int numHands;

  /// Minimum palm detection confidence.
  final double minHandDetectionConfidence;

  /// Minimum hand presence confidence from the landmark model.
  final double minHandPresenceConfidence;

  /// Minimum tracking confidence in video and live stream modes.
  final double minTrackingConfidence;
}

/// Options for the official Hand Landmarker.
final class HandLandmarkerOptions extends HandTrackingOptions {
  /// Supply the task bundle and optional tracking thresholds.
  HandLandmarkerOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    super.numHands,
    super.minHandDetectionConfidence,
    super.minHandPresenceConfidence,
    super.minTrackingConfidence,
  });
}

/// Classification filters for a model head, as Gesture Recognizer nests them
/// for its canned and custom gestures.
final class ClassifierOptions implements ClassifierSettings {
  /// A negative [maxResults] returns every category.
  ClassifierOptions({
    this.maxResults = -1,
    this.scoreThreshold = 0,
    this.displayNamesLocale,
    List<String>? categoryAllowlist,
    List<String>? categoryDenylist,
  }) : categoryAllowlist = List.unmodifiable(categoryAllowlist ?? const []),
       categoryDenylist = List.unmodifiable(categoryDenylist ?? const []) {
    checkClassifierSettings(this);
  }

  /// Maximum categories per head; negative returns all of them.
  @override
  final int maxResults;

  /// Categories scoring below this are dropped.
  @override
  final double scoreThreshold;

  /// Locale of the display names in the model metadata.
  @override
  final String? displayNamesLocale;

  /// Category names to keep; exclusive with [categoryDenylist].
  @override
  final List<String> categoryAllowlist;

  /// Category names to drop; exclusive with [categoryAllowlist].
  @override
  final List<String> categoryDenylist;
}

/// Options for the official Gesture Recognizer.
final class GestureRecognizerOptions extends HandTrackingOptions {
  /// Supply a task bundle with canned and optional custom gestures.
  GestureRecognizerOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    super.numHands,
    super.minHandDetectionConfidence,
    super.minHandPresenceConfidence,
    super.minTrackingConfidence,
    ClassifierOptions? cannedGesturesClassifierOptions,
    ClassifierOptions? customGesturesClassifierOptions,
  }) : cannedGesturesClassifierOptions =
           cannedGesturesClassifierOptions ?? ClassifierOptions(),
       customGesturesClassifierOptions =
           customGesturesClassifierOptions ?? ClassifierOptions();

  /// Filters for the model's built-in gestures.
  final ClassifierOptions cannedGesturesClassifierOptions;

  /// Filters for custom gestures, when the task bundle has them.
  final ClassifierOptions customGesturesClassifierOptions;
}

/// Options for the official Pose Landmarker.
final class PoseLandmarkerOptions extends VisionTaskOptions {
  /// Defaults match Google's.
  PoseLandmarkerOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.numPoses = 1,
    this.minPoseDetectionConfidence = 0.5,
    this.minPosePresenceConfidence = 0.5,
    this.minTrackingConfidence = 0.5,
    this.outputSegmentationMasks = false,
  }) {
    checkCount(numPoses, 'numPoses');
    checkConfidence(minPoseDetectionConfidence, 'minPoseDetectionConfidence');
    checkConfidence(minPosePresenceConfidence, 'minPosePresenceConfidence');
    checkConfidence(minTrackingConfidence, 'minTrackingConfidence');
  }

  /// Maximum number of detected poses.
  final int numPoses;

  /// Minimum person detection confidence.
  final double minPoseDetectionConfidence;

  /// Minimum pose presence confidence.
  final double minPosePresenceConfidence;

  /// Minimum tracking confidence in video and live stream modes.
  final double minTrackingConfidence;

  /// Include one foreground confidence mask per pose.
  final bool outputSegmentationMasks;
}

/// Options for the official Holistic Landmarker.
final class HolisticLandmarkerOptions extends VisionTaskOptions {
  /// Defaults match Google's.
  HolisticLandmarkerOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.minFaceDetectionConfidence = 0.5,
    this.minFaceSuppressionThreshold = 0.5,
    this.minFacePresenceConfidence = 0.5,
    this.minHandLandmarksConfidence = 0.5,
    this.minPoseDetectionConfidence = 0.5,
    this.minPoseSuppressionThreshold = 0.5,
    this.minPosePresenceConfidence = 0.5,
    this.outputFaceBlendshapes = false,
    this.outputPoseSegmentationMask = false,
  }) {
    for (final (name, value) in [
      ('minFaceDetectionConfidence', minFaceDetectionConfidence),
      ('minFaceSuppressionThreshold', minFaceSuppressionThreshold),
      ('minFacePresenceConfidence', minFacePresenceConfidence),
      ('minHandLandmarksConfidence', minHandLandmarksConfidence),
      ('minPoseDetectionConfidence', minPoseDetectionConfidence),
      ('minPoseSuppressionThreshold', minPoseSuppressionThreshold),
      ('minPosePresenceConfidence', minPosePresenceConfidence),
    ]) {
      checkConfidence(value, name);
    }
  }

  /// Minimum face detection confidence.
  final double minFaceDetectionConfidence;

  /// Face non-maximum suppression threshold.
  final double minFaceSuppressionThreshold;

  /// Minimum face landmark presence confidence.
  final double minFacePresenceConfidence;

  /// Minimum hand landmark confidence.
  final double minHandLandmarksConfidence;

  /// Minimum pose detection confidence.
  final double minPoseDetectionConfidence;

  /// Pose non-maximum suppression threshold.
  final double minPoseSuppressionThreshold;

  /// Minimum pose landmark presence confidence.
  final double minPosePresenceConfidence;

  /// Include face blendshapes when a face is found.
  final bool outputFaceBlendshapes;

  /// Include the pose foreground confidence mask.
  final bool outputPoseSegmentationMask;
}

/// Options for the official Object Detector.
final class ObjectDetectorOptions extends VisionTaskOptions
    implements ClassifierSettings {
  /// Defaults match Google's.
  ObjectDetectorOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.displayNamesLocale,
    this.maxResults = -1,
    this.scoreThreshold = 0,
    List<String>? categoryAllowlist,
    List<String>? categoryDenylist,
  }) : categoryAllowlist = List.unmodifiable(categoryAllowlist ?? const []),
       categoryDenylist = List.unmodifiable(categoryDenylist ?? const []) {
    checkClassifierSettings(this);
  }

  /// Locale of the display names in the model metadata.
  @override
  final String? displayNamesLocale;

  /// Maximum detections; negative for Google's own limit.
  @override
  final int maxResults;

  /// Detections scoring below this are dropped.
  @override
  final double scoreThreshold;

  /// Category names to keep; exclusive with [categoryDenylist].
  @override
  final List<String> categoryAllowlist;

  /// Category names to drop; exclusive with [categoryAllowlist].
  @override
  final List<String> categoryDenylist;
}

/// Options for the official Image Classifier.
final class ImageClassifierOptions extends VisionTaskOptions
    implements ClassifierSettings {
  /// Defaults match Google's.
  ImageClassifierOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.displayNamesLocale,
    this.maxResults = -1,
    this.scoreThreshold = 0,
    List<String>? categoryAllowlist,
    List<String>? categoryDenylist,
  }) : categoryAllowlist = List.unmodifiable(categoryAllowlist ?? const []),
       categoryDenylist = List.unmodifiable(categoryDenylist ?? const []) {
    checkClassifierSettings(this);
  }

  /// Locale of the display names in the model metadata.
  @override
  final String? displayNamesLocale;

  /// Maximum categories per head; negative returns all of them.
  @override
  final int maxResults;

  /// Categories scoring below this are dropped.
  @override
  final double scoreThreshold;

  /// Category names to keep; exclusive with [categoryDenylist].
  @override
  final List<String> categoryAllowlist;

  /// Category names to drop; exclusive with [categoryAllowlist].
  @override
  final List<String> categoryDenylist;
}

/// Options for the official Image Embedder.
final class ImageEmbedderOptions extends VisionTaskOptions {
  /// Google's graph handles preprocessing, normalization and quantization.
  ImageEmbedderOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.l2Normalize = false,
    this.quantize = false,
  });

  /// Normalize vectors with the L2 norm when the model does not already.
  final bool l2Normalize;

  /// Return scalar-quantized bytes instead of float vectors.
  final bool quantize;
}

/// Options for the official Image Segmenter.
final class ImageSegmenterOptions extends VisionTaskOptions {
  /// Request confidence masks, a category mask or both.
  ImageSegmenterOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.runningMode,
    super.delegate,
    this.outputConfidenceMasks = true,
    this.outputCategoryMask = false,
    this.displayNamesLocale,
  }) {
    if (!outputConfidenceMasks && !outputCategoryMask) {
      throw ArgumentError(
        'Request a confidence mask, a category mask or both.',
      );
    }
    if (displayNamesLocale case final locale?) {
      checkLabel(locale, 'displayNamesLocale');
    }
  }

  /// One float32 confidence mask per category.
  final bool outputConfidenceMasks;

  /// One uint8 mask holding the winning category per pixel.
  final bool outputCategoryMask;

  /// Locale of the label list in the model metadata; the model's own by
  /// default.
  final String? displayNamesLocale;
}

/// Options for Google's stateful MagicTouch Interactive Segmenter, which
/// takes an image and then stroke histories.
final class InteractiveSegmenterOptions extends VisionTaskOptions {
  /// Supply the official task bundle; the task has no video mode.
  InteractiveSegmenterOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
  });
}

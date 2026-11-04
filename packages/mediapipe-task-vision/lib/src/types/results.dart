/// The results of every vision task: immutable Dart values on the shared
/// value types, owned by the caller and valid after the task is disposed.
library;

import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:meta/meta.dart';

import 'vision_types.dart';

/// What every vision task's result reports about its input: the decoded
/// size and, in video and live stream modes, the frame's timestamp.
@immutable
abstract base class VisionResult {
  /// Records the input's size and the frame's timestamp.
  const VisionResult({
    required this.imageWidth,
    required this.imageHeight,
    this.timestampMilliseconds,
  });

  /// Decoded input width, after any EXIF orientation correction.
  final int imageWidth;

  /// Decoded input height, after any EXIF orientation correction.
  final int imageHeight;

  /// The frame's timestamp in video and live stream modes, null for a
  /// still image.
  final int? timestampMilliseconds;
}

/// The faces in an image: each a box, a score and six keypoints (right eye,
/// left eye, nose tip, mouth, right tragion, left tragion).
@immutable
final class FaceDetectorResult extends VisionResult {
  /// Owns an unmodifiable copy of [detections].
  FaceDetectorResult({
    required super.imageWidth,
    required super.imageHeight,
    required List<Detection> detections,
    super.timestampMilliseconds,
  }) : detections = List.unmodifiable(detections);

  /// Detections in the runtime's order.
  final List<Detection> detections;

  @override
  String toString() =>
      'FaceDetectorResult(${detections.length} detections, '
      '$imageWidth x $imageHeight, timestamp: $timestampMilliseconds)';
}

/// The objects in an image: each a box and its categories.
@immutable
final class ObjectDetectorResult extends VisionResult {
  /// Owns an unmodifiable copy of [detections].
  ObjectDetectorResult({
    required super.imageWidth,
    required super.imageHeight,
    required List<Detection> detections,
    super.timestampMilliseconds,
  }) : detections = List.unmodifiable(detections);

  /// Detections in the runtime's order.
  final List<Detection> detections;

  @override
  String toString() =>
      'ObjectDetectorResult(${detections.length} detections, '
      '$imageWidth x $imageHeight, timestamp: $timestampMilliseconds)';
}

/// The 478 landmarks of each face, with the optional blendshapes and
/// transformation matrixes.
@immutable
final class FaceLandmarkerResult extends VisionResult {
  /// Owns unmodifiable copies of the lists, in the runtime's order.
  FaceLandmarkerResult({
    required super.imageWidth,
    required super.imageHeight,
    required List<List<NormalizedLandmark>> faceLandmarks,
    required List<List<MediaPipeCategory>> faceBlendshapes,
    required List<Matrix> facialTransformationMatrixes,
    super.timestampMilliseconds,
  }) : faceLandmarks = ownNestedLists(faceLandmarks),
       faceBlendshapes = ownNestedLists(faceBlendshapes),
       facialTransformationMatrixes = List.unmodifiable(
         facialTransformationMatrixes,
       );

  /// 478 landmarks per face from the official bundle, both irises included.
  final List<List<NormalizedLandmark>> faceLandmarks;

  /// 52 expression scores per face; empty when not requested or no face.
  final List<List<MediaPipeCategory>> faceBlendshapes;

  /// One 4 x 4 matrix per face; empty when not requested or no face.
  final List<Matrix> facialTransformationMatrixes;

  @override
  String toString() =>
      'FaceLandmarkerResult(${faceLandmarks.length} faces, '
      '$imageWidth x $imageHeight, timestamp: $timestampMilliseconds)';
}

/// The 21 landmarks of each hand, in image and world space, with handedness.
@immutable
final class HandLandmarkerResult extends VisionResult {
  /// Owns unmodifiable copies of the lists, ordered alike.
  HandLandmarkerResult({
    required List<List<MediaPipeCategory>> handedness,
    required List<List<NormalizedLandmark>> handLandmarks,
    required List<List<Landmark>> handWorldLandmarks,
    required super.imageWidth,
    required super.imageHeight,
    super.timestampMilliseconds,
  }) : handedness = ownNestedLists(handedness),
       handLandmarks = ownNestedLists(handLandmarks),
       handWorldLandmarks = ownNestedLists(handWorldLandmarks);

  /// Left or right, per hand.
  final List<List<MediaPipeCategory>> handedness;

  /// Image-space landmarks, 21 per hand.
  final List<List<NormalizedLandmark>> handLandmarks;

  /// World landmarks in meters, 21 per hand.
  final List<List<Landmark>> handWorldLandmarks;

  @override
  String toString() =>
      'HandLandmarkerResult(${handLandmarks.length} hands, '
      '$imageWidth x $imageHeight, timestamp: $timestampMilliseconds)';
}

/// The gestures and landmarks of each hand.
@immutable
final class GestureRecognizerResult extends VisionResult {
  /// Owns unmodifiable copies of the lists, ordered alike.
  GestureRecognizerResult({
    required List<List<MediaPipeCategory>> gestures,
    required List<List<MediaPipeCategory>> handedness,
    required List<List<NormalizedLandmark>> handLandmarks,
    required List<List<Landmark>> handWorldLandmarks,
    required super.imageWidth,
    required super.imageHeight,
    super.timestampMilliseconds,
  }) : gestures = ownNestedLists(gestures),
       handedness = ownNestedLists(handedness),
       handLandmarks = ownNestedLists(handLandmarks),
       handWorldLandmarks = ownNestedLists(handWorldLandmarks);

  /// Canned and custom gestures per hand, best first.
  ///
  /// Each category's index is -1: canned and custom classifiers number their
  /// labels independently, so a merged index would carry no meaning.
  final List<List<MediaPipeCategory>> gestures;

  /// Left or right, per hand.
  final List<List<MediaPipeCategory>> handedness;

  /// Image-space landmarks, 21 per hand.
  final List<List<NormalizedLandmark>> handLandmarks;

  /// World landmarks in meters, 21 per hand.
  final List<List<Landmark>> handWorldLandmarks;

  @override
  String toString() =>
      'GestureRecognizerResult(${handLandmarks.length} hands, '
      '$imageWidth x $imageHeight, timestamp: $timestampMilliseconds)';
}

/// The 33 landmarks of each pose, in image and world space, with optional
/// foreground masks.
@immutable
final class PoseLandmarkerResult extends VisionResult {
  /// Owns unmodifiable copies of the lists and masks.
  PoseLandmarkerResult({
    required List<List<NormalizedLandmark>> poseLandmarks,
    required List<List<Landmark>> poseWorldLandmarks,
    List<ConfidenceMask>? segmentationMasks,
    required super.imageWidth,
    required super.imageHeight,
    super.timestampMilliseconds,
  }) : poseLandmarks = ownNestedLists(poseLandmarks),
       poseWorldLandmarks = ownNestedLists(poseWorldLandmarks),
       segmentationMasks = segmentationMasks == null
           ? null
           : List.unmodifiable(segmentationMasks);

  /// Image-space landmarks, 33 per pose.
  final List<List<NormalizedLandmark>> poseLandmarks;

  /// World landmarks in meters, 33 per pose.
  final List<List<Landmark>> poseWorldLandmarks;

  /// One foreground mask per pose, or null when not requested.
  final List<ConfidenceMask>? segmentationMasks;

  @override
  String toString() =>
      'PoseLandmarkerResult(${poseLandmarks.length} poses, '
      '$imageWidth x $imageHeight, timestamp: $timestampMilliseconds)';
}

/// The face, pose and hand landmarks of one person.
@immutable
final class HolisticLandmarkerResult extends VisionResult {
  /// Owns unmodifiable copies of the lists and the optional outputs.
  HolisticLandmarkerResult({
    required List<NormalizedLandmark> faceLandmarks,
    required List<NormalizedLandmark> poseLandmarks,
    required List<Landmark> poseWorldLandmarks,
    required List<NormalizedLandmark> leftHandLandmarks,
    required List<NormalizedLandmark> rightHandLandmarks,
    required List<Landmark> leftHandWorldLandmarks,
    required List<Landmark> rightHandWorldLandmarks,
    List<MediaPipeCategory>? faceBlendshapes,
    this.poseSegmentationMask,
    required super.imageWidth,
    required super.imageHeight,
    super.timestampMilliseconds,
  }) : faceLandmarks = List.unmodifiable(faceLandmarks),
       poseLandmarks = List.unmodifiable(poseLandmarks),
       poseWorldLandmarks = List.unmodifiable(poseWorldLandmarks),
       leftHandLandmarks = List.unmodifiable(leftHandLandmarks),
       rightHandLandmarks = List.unmodifiable(rightHandLandmarks),
       leftHandWorldLandmarks = List.unmodifiable(leftHandWorldLandmarks),
       rightHandWorldLandmarks = List.unmodifiable(rightHandWorldLandmarks),
       faceBlendshapes = faceBlendshapes == null
           ? null
           : List.unmodifiable(faceBlendshapes);

  /// Image-space face landmarks; empty when no face was found.
  final List<NormalizedLandmark> faceLandmarks;

  /// Image-space pose landmarks; empty when no pose was found.
  final List<NormalizedLandmark> poseLandmarks;

  /// Pose world landmarks in meters.
  final List<Landmark> poseWorldLandmarks;

  /// Image-space left hand landmarks; empty when not found.
  final List<NormalizedLandmark> leftHandLandmarks;

  /// Image-space right hand landmarks; empty when not found.
  final List<NormalizedLandmark> rightHandLandmarks;

  /// Left hand world landmarks in meters.
  final List<Landmark> leftHandWorldLandmarks;

  /// Right hand world landmarks in meters.
  final List<Landmark> rightHandWorldLandmarks;

  /// Face blendshapes, or null when not requested or no face was found.
  final List<MediaPipeCategory>? faceBlendshapes;

  /// The pose foreground mask, or null when not requested or absent.
  final ConfidenceMask? poseSegmentationMask;

  @override
  String toString() =>
      'HolisticLandmarkerResult(face: ${faceLandmarks.length}, '
      'pose: ${poseLandmarks.length}, hands: ${leftHandLandmarks.length}/'
      '${rightHandLandmarks.length}, $imageWidth x $imageHeight, '
      'timestamp: $timestampMilliseconds)';
}

/// The categories of every classifier head.
@immutable
final class ImageClassifierResult extends VisionResult {
  /// Owns an unmodifiable copy of [classifications].
  ImageClassifierResult({
    required List<Classifications> classifications,
    required super.imageWidth,
    required super.imageHeight,
    super.timestampMilliseconds,
  }) : classifications = List.unmodifiable(classifications);

  /// One entry per model head, in the runtime's order.
  final List<Classifications> classifications;

  @override
  String toString() =>
      'ImageClassifierResult($classifications, $imageWidth x $imageHeight, '
      'timestamp: $timestampMilliseconds)';
}

/// The vectors of every embedder head.
@immutable
final class ImageEmbedderResult extends VisionResult {
  /// Owns an unmodifiable copy of [embeddings].
  ImageEmbedderResult({
    required List<Embedding> embeddings,
    required super.imageWidth,
    required super.imageHeight,
    super.timestampMilliseconds,
  }) : embeddings = List.unmodifiable(embeddings);

  /// One entry per model head, in the runtime's order.
  final List<Embedding> embeddings;

  @override
  String toString() =>
      'ImageEmbedderResult($embeddings, $imageWidth x $imageHeight, '
      'timestamp: $timestampMilliseconds)';
}

/// The masks the Image Segmenter was asked for.
@immutable
final class ImageSegmenterResult extends VisionResult {
  /// Owns unmodifiable copies of the masks and scores.
  ImageSegmenterResult({
    List<ConfidenceMask>? confidenceMasks,
    this.categoryMask,
    Float32List? qualityScores,
    List<String> labels = const [],
    required super.imageWidth,
    required super.imageHeight,
    super.timestampMilliseconds,
  }) : labels = List.unmodifiable(labels),
       confidenceMasks = confidenceMasks == null
           ? null
           : List.unmodifiable(confidenceMasks),
       qualityScores = qualityScores == null
           ? null
           : Float32List.fromList(qualityScores).asUnmodifiableView();

  /// One confidence mask per category, or null when not requested.
  final List<ConfidenceMask>? confidenceMasks;

  /// The winning category per pixel, or null when not requested.
  final CategoryMask? categoryMask;

  /// Per-category quality in `[0, 1]`, or null when the model reports none.
  ///
  /// Google's Python bindings drop this field, so it has no independent
  /// reference output; only its shape and range are checked.
  final Float32List? qualityScores;

  /// The model's category order, which indexes both mask kinds.
  ///
  /// Repeated on every result because the native task stays on its worker
  /// isolate and cannot be queried from the calling isolate.
  final List<String> labels;

  @override
  String toString() =>
      'ImageSegmenterResult(${confidenceMasks?.length ?? 0} confidence masks, '
      '${categoryMask == null ? 'no' : 'a'} category mask, '
      '$imageWidth x $imageHeight, timestamp: $timestampMilliseconds)';
}

/// One decoder from the browser adapter's results to the Dart types.
///
/// Google's browser runtime delivers results through [VisionResultData]: the
/// result fields in the JSON shape of its JavaScript API, with image
/// landmarks and masks kept as packed typed arrays. The adapter only
/// reshapes; every value is read here.
library;

import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show decodeCategory, decodeClassifications, decodeEmbedding, decodeLabel;

import '../types/results.dart';
import 'landmark_codec.dart';

/// A result as an adapter delivers it.
final class VisionResultData {
  /// [result] holds the task's fields in Google's JavaScript shape, except
  /// that masks arrive as `[width, height, Float32List or Uint8List]` and
  /// that packed landmarks replace the image-space landmarks' JSON lists:
  /// [landmarks] with [counts] (points per subject). Holistic packs every
  /// part into [landmarks] in the order of [parts], each entry a part name
  /// and its points per subject.
  const VisionResultData({
    required this.result,
    required this.width,
    required this.height,
    this.timestamp,
    this.landmarks,
    this.counts,
    this.parts,
  });

  /// Reads the browser worker's reply: its decoded JSON (`width`, `height`,
  /// `timestamp`, `result`, and `counts` or `parts` when the worker packed
  /// the image landmarks) with the packed [landmarks] it transferred.
  factory VisionResultData.fromBrowser(
    Map<String, dynamic> json, {
    Float64List? landmarks,
  }) => VisionResultData(
    result: json['result'] as Map<String, dynamic>,
    width: json['width'] as int,
    height: json['height'] as int,
    timestamp: json['timestamp'] as int?,
    landmarks: landmarks,
    counts: (json['counts'] as List?)?.cast<int>(),
    parts: switch (json['parts']) {
      final List parts => [
        for (final entry in parts.cast<List>())
          (entry[0] as String, (entry[1] as List).cast<int>()),
      ],
      _ => null,
    },
  );

  /// The task's result fields.
  final Map<String, dynamic> result;

  /// Decoded input width.
  final int width;

  /// Decoded input height.
  final int height;

  /// The frame's timestamp in video mode.
  final int? timestamp;

  /// Packed image-space landmarks, five doubles per point.
  final Float64List? landmarks;

  /// Points per subject in [landmarks].
  final List<int>? counts;

  /// Holistic's packed parts, in the order they appear in [landmarks].
  final List<(String, List<int>)>? parts;
}

/// Decodes a Face Landmarker result.
FaceLandmarkerResult decodeFaceLandmarkerResult(VisionResultData data) =>
    FaceLandmarkerResult(
      imageWidth: data.width,
      imageHeight: data.height,
      timestampMilliseconds: data.timestamp,
      faceLandmarks: _imageLandmarks(data, 'faceLandmarks'),
      faceBlendshapes: [
        for (final face in data.result['faceBlendshapes'] as List)
          _categories((face as Map)['categories']),
      ],
      facialTransformationMatrixes: [
        for (final raw in data.result['facialTransformationMatrixes'] as List)
          Matrix(
            rows: (raw as Map)['rows'] as int,
            columns: raw['columns'] as int,
            data: [for (final value in raw['data'] as List) _number(value)],
          ),
      ],
    );

/// Decodes a Hand Landmarker result.
HandLandmarkerResult decodeHandLandmarkerResult(VisionResultData data) =>
    HandLandmarkerResult(
      imageWidth: data.width,
      imageHeight: data.height,
      timestampMilliseconds: data.timestamp,
      handLandmarks: _imageLandmarks(data, 'landmarks'),
      handWorldLandmarks: _worldLandmarks(data, 'worldLandmarks'),
      handedness: _categoryLists(data.result['handedness']),
    );

/// Decodes a Gesture Recognizer result.
GestureRecognizerResult decodeGestureRecognizerResult(VisionResultData data) =>
    GestureRecognizerResult(
      imageWidth: data.width,
      imageHeight: data.height,
      timestampMilliseconds: data.timestamp,
      handLandmarks: _imageLandmarks(data, 'landmarks'),
      handWorldLandmarks: _worldLandmarks(data, 'worldLandmarks'),
      handedness: _categoryLists(data.result['handedness']),
      gestures: [
        for (final hand in data.result['gestures'] as List)
          [
            // Canned and custom labels are numbered independently, so the
            // merged index carries no meaning; Google's C API reports -1.
            for (final gesture in _categories(hand))
              MediaPipeCategory(
                index: -1,
                score: gesture.score,
                categoryName: gesture.categoryName,
                displayName: gesture.displayName,
              ),
          ],
      ],
    );

/// Decodes a Pose Landmarker result.
PoseLandmarkerResult decodePoseLandmarkerResult(VisionResultData data) =>
    PoseLandmarkerResult(
      imageWidth: data.width,
      imageHeight: data.height,
      timestampMilliseconds: data.timestamp,
      poseLandmarks: _imageLandmarks(data, 'landmarks'),
      poseWorldLandmarks: _worldLandmarks(data, 'worldLandmarks'),
      segmentationMasks: _confidenceMasks(data.result['segmentationMasks']),
    );

/// Decodes a Holistic Landmarker result. Google's browser API lists each part
/// per subject; Holistic reports at most one.
HolisticLandmarkerResult decodeHolisticLandmarkerResult(VisionResultData data) {
  final packed = <String, List<List<NormalizedLandmark>>>{};
  final packedWorld = <String, List<List<Landmark>>>{};
  if (data.landmarks case final buffer?) {
    var at = 0;
    for (final (name, counts) in data.parts ?? const <(String, List<int>)>[]) {
      final end = at + counts.fold(0, (a, b) => a + b) * packedLandmarkStride;
      final view = Float64List.sublistView(buffer, at, end);
      if (name.endsWith('WorldLandmarks')) {
        packedWorld[name] = unpackLandmarks(view, counts, Landmark.new);
      } else {
        packed[name] = unpackLandmarks(view, counts, NormalizedLandmark.new);
      }
      at = end;
    }
  }
  List<NormalizedLandmark> part(String name) {
    final subjects =
        packed[name] ??
        _jsonLandmarks(data.result[name], NormalizedLandmark.new);
    return subjects.isEmpty ? const [] : subjects.first;
  }

  List<Landmark> worldPart(String name) {
    final subjects =
        packedWorld[name] ?? _jsonLandmarks(data.result[name], Landmark.new);
    return subjects.isEmpty ? const [] : subjects.first;
  }

  final blendshapes = data.result['faceBlendshapes'] as List?;
  return HolisticLandmarkerResult(
    imageWidth: data.width,
    imageHeight: data.height,
    timestampMilliseconds: data.timestamp,
    faceLandmarks: part('faceLandmarks'),
    poseLandmarks: part('poseLandmarks'),
    poseWorldLandmarks: worldPart('poseWorldLandmarks'),
    leftHandLandmarks: part('leftHandLandmarks'),
    leftHandWorldLandmarks: worldPart('leftHandWorldLandmarks'),
    rightHandLandmarks: part('rightHandLandmarks'),
    rightHandWorldLandmarks: worldPart('rightHandWorldLandmarks'),
    faceBlendshapes: blendshapes == null || blendshapes.isEmpty
        ? null
        : _categories((blendshapes.first as Map)['categories']),
    poseSegmentationMask: _confidenceMasks(
      data.result['poseSegmentationMasks'],
    )?.firstOrNull,
  );
}

/// Decodes a Face Detector result. Google's boxes are float pixels; the Dart
/// boxes are whole pixels, truncated as the C API does.
FaceDetectorResult decodeFaceDetectorResult(VisionResultData data) =>
    FaceDetectorResult(
      imageWidth: data.width,
      imageHeight: data.height,
      timestampMilliseconds: data.timestamp,
      detections: [
        for (final d in data.result['detections'] as List)
          Detection(
            boundingBox: _box((d as Map)['boundingBox']),
            categories: _categories(d['categories']),
            keypoints: [
              for (final k in (d['keypoints'] as List?) ?? const [])
                NormalizedKeypoint(
                  x: _number((k as Map)['x']),
                  y: _number(k['y']),
                  label: decodeLabel(k['label']),
                  score: _optional(k['score']),
                ),
            ],
          ),
      ],
    );

/// Decodes an Object Detector result, boxes as for faces.
ObjectDetectorResult decodeObjectDetectorResult(VisionResultData data) =>
    ObjectDetectorResult(
      imageWidth: data.width,
      imageHeight: data.height,
      timestampMilliseconds: data.timestamp,
      detections: [
        for (final d in data.result['detections'] as List)
          Detection(
            boundingBox: _box((d as Map)['boundingBox']),
            categories: _categories(d['categories']),
          ),
      ],
    );

/// Decodes an Image Classifier result.
ImageClassifierResult decodeImageClassifierResult(VisionResultData data) =>
    ImageClassifierResult(
      imageWidth: data.width,
      imageHeight: data.height,
      timestampMilliseconds: data.timestamp,
      classifications: [
        for (final head in data.result['classifications'] as List)
          decodeClassifications(head as Map),
      ],
    );

/// Decodes an Image Embedder result: one vector per model head.
ImageEmbedderResult decodeImageEmbedderResult(VisionResultData data) =>
    ImageEmbedderResult(
      imageWidth: data.width,
      imageHeight: data.height,
      timestampMilliseconds: data.timestamp,
      embeddings: [
        for (final head in data.result['embeddings'] as List)
          decodeEmbedding(head as Map),
      ],
    );

/// Decodes an Image Segmenter result.
ImageSegmenterResult decodeImageSegmenterResult(VisionResultData data) {
  final category = data.result['categoryMask'] as List?;
  return ImageSegmenterResult(
    imageWidth: data.width,
    imageHeight: data.height,
    timestampMilliseconds: data.timestamp,
    confidenceMasks: _confidenceMasks(data.result['confidenceMasks']),
    categoryMask: category == null
        ? null
        : CategoryMask(
            width: category[0] as int,
            height: category[1] as int,
            categories: category[2] as Uint8List,
          ),
    qualityScores: switch (data.result['qualityScores']) {
      final Float32List scores => scores,
      final List scores => Float32List.fromList([
        for (final score in scores) _number(score),
      ]),
      _ => null,
    },
    labels: [
      for (final label in data.result['labels'] as List? ?? const []) '$label',
    ],
  );
}

/// Replaces each mask the browser worker named as `[width, height, bytes per
/// value, index]` in [result] with `[width, height, values]` read from
/// [buffers]: float32 confidences or uint8 categories.
void attachMaskBuffers(Map<String, dynamic> result, List<ByteBuffer> buffers) {
  List<Object> mask(List named) {
    final [width as int, height as int, depth as int, index as int] = named;
    final bytes = buffers[index];
    if (bytes.lengthInBytes != width * height * depth) {
      throw StateError('Mask $index has ${bytes.lengthInBytes} bytes.');
    }
    return [
      width,
      height,
      depth == 1 ? bytes.asUint8List() : bytes.asFloat32List(),
    ];
  }

  for (final key in const [
    'confidenceMasks',
    'segmentationMasks',
    'poseSegmentationMasks',
  ]) {
    if (result[key] case final List masks) {
      result[key] = [for (final named in masks) mask(named as List)];
    }
  }
  if (result['categoryMask'] case final List named) {
    result['categoryMask'] = mask(named);
  }
}

/// Packs one `[width, height, Float32List]` mask list as a confidence mask.
ConfidenceMask confidenceMaskFromList(List mask) => ConfidenceMask(
  width: mask[0] as int,
  height: mask[1] as int,
  confidence: mask[2] as Float32List,
);

List<ConfidenceMask>? _confidenceMasks(Object? masks) => masks is List
    ? [for (final mask in masks.cast<List>()) confidenceMaskFromList(mask)]
    : null;

/// A box as Google's browser API reports it (`originX`, `originY`, `width`,
/// `height`).
BoundingBox _box(Object? json) {
  final box = json as Map;
  final left = _number(box['originX']), top = _number(box['originY']);
  return BoundingBox(
    left: left.toInt(),
    top: top.toInt(),
    right: (left + _number(box['width'])).toInt(),
    bottom: (top + _number(box['height'])).toInt(),
  );
}

double _number(Object? value) => (value as num).toDouble();
double? _optional(Object? value) => value == null ? null : _number(value);

List<List<NormalizedLandmark>> _imageLandmarks(
  VisionResultData data,
  String key,
) {
  if (data.landmarks case final packed?) {
    return unpackLandmarks(packed, data.counts!, NormalizedLandmark.new);
  }
  return _jsonLandmarks(data.result[key], NormalizedLandmark.new);
}

List<List<Landmark>> _worldLandmarks(VisionResultData data, String key) =>
    _jsonLandmarks(data.result[key], Landmark.new);

List<List<T>> _jsonLandmarks<T>(Object? json, LandmarkBuilder<T> point) => [
  for (final subject in (json as List?) ?? const [])
    [
      for (final raw in subject as List)
        point(
          x: _number((raw as Map)['x']),
          y: _number(raw['y']),
          z: _number(raw['z']),
          name: raw['name'] as String?,
          visibility: _optional(raw['visibility']),
          presence: _optional(raw['presence']),
        ),
    ],
];

List<List<MediaPipeCategory>> _categoryLists(Object? json) => [
  for (final subject in json as List) _categories(subject),
];

List<MediaPipeCategory> _categories(Object? json) => [
  for (final raw in json as List) decodeCategory(raw as Map),
];

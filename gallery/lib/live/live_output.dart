import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../ui/components.dart';

/// What a vision result shows in the Output card: a title, a count beside
/// it, and scores as bars.
typedef LiveOutput = ({
  String title,
  String? count,
  List<Score> items,
  String empty,
});

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';

String _name(String? display, String? category, int index) =>
    (display?.isNotEmpty ?? false)
    ? display!
    : (category?.isNotEmpty ?? false)
    ? category!
    : 'Class $index';

/// The top [n] of [scores], highest first.
List<Score> _top(Iterable<Score> scores, [int n = 5]) =>
    (scores.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(n)
        .toList();

/// The Output card's content for [result], or null before the first one.
LiveOutput? liveOutput(Object? result) => switch (result) {
  FaceLandmarkerResult(:final faceLandmarks, :final faceBlendshapes) => (
    title: faceBlendshapes.isEmpty ? 'Faces' : 'Top blendshapes',
    count: faceLandmarks.isEmpty
        ? _plural(0, 'face')
        : _plural(faceLandmarks.first.length, 'landmark'),
    items: faceBlendshapes.isEmpty
        ? [
            for (final (i, _) in faceLandmarks.indexed)
              (name: 'Face ${i + 1}', value: 1.0),
          ]
        : _top([
            for (final category in faceBlendshapes.first)
              (
                name: _name(
                  category.displayName,
                  category.categoryName,
                  category.index,
                ),
                value: category.score,
              ),
          ], 4),
    empty: 'No face in view.',
  ),
  FaceDetectorResult(:final detections) => (
    title: 'Detections',
    count: _plural(detections.length, 'face'),
    items: [
      for (final (i, detection) in detections.indexed)
        (
          name: 'Face ${i + 1}',
          value: detection.categories.firstOrNull?.score ?? 0,
        ),
    ],
    empty: 'No face in view.',
  ),
  GestureRecognizerResult(:final gestures, :final handedness) => (
    title: 'Gestures',
    count: _plural(handedness.length, 'hand'),
    items: [
      for (final (i, hand) in handedness.indexed) ...[
        if (hand.firstOrNull case final side?)
          (
            name: '${_name(side.displayName, side.categoryName, i)} hand',
            value: side.score,
          ),
        if (i < gestures.length)
          if (gestures[i].firstOrNull case final gesture?)
            (
              name: _name(
                gesture.displayName,
                gesture.categoryName,
                gesture.index,
              ),
              value: gesture.score,
            ),
      ],
    ],
    empty: 'No hand in view.',
  ),
  HandLandmarkerResult(:final handedness, :final handLandmarks) => (
    title: 'Handedness',
    count: handLandmarks.isEmpty
        ? _plural(0, 'hand')
        : _plural(handLandmarks.first.length, 'landmark'),
    items: [
      for (final (i, hand) in handedness.indexed)
        if (hand.firstOrNull case final side?)
          (
            name: '${_name(side.displayName, side.categoryName, i)} hand',
            value: side.score,
          ),
    ],
    empty: 'No hand in view.',
  ),
  PoseLandmarkerResult(:final poseLandmarks) => (
    title: 'Poses',
    count: poseLandmarks.isEmpty
        ? _plural(0, 'pose')
        : _plural(poseLandmarks.first.length, 'landmark'),
    items: [
      for (final (i, pose) in poseLandmarks.indexed)
        (name: 'Pose ${i + 1} visibility', value: _visibility(pose)),
    ],
    empty: 'No pose in view.',
  ),
  HolisticLandmarkerResult(
    :final faceLandmarks,
    :final poseLandmarks,
    :final leftHandLandmarks,
    :final rightHandLandmarks,
  ) =>
    (
      title: 'Detected parts',
      count: _plural(
        faceLandmarks.length +
            poseLandmarks.length +
            leftHandLandmarks.length +
            rightHandLandmarks.length,
        'landmark',
      ),
      items: [
        if (poseLandmarks.isNotEmpty)
          (name: 'Body visibility', value: _visibility(poseLandmarks)),
        if (faceLandmarks.isNotEmpty) (name: 'Face', value: 1.0),
        if (leftHandLandmarks.isNotEmpty) (name: 'Left hand', value: 1.0),
        if (rightHandLandmarks.isNotEmpty) (name: 'Right hand', value: 1.0),
      ],
      empty: 'No body in view.',
    ),
  ObjectDetectorResult(:final detections) => (
    title: 'Detections',
    count: _plural(detections.length, 'object'),
    items: _top([
      for (final detection in detections)
        if (detection.categories.firstOrNull case final category?)
          (
            name: _name(
              category.displayName,
              category.categoryName,
              category.index,
            ),
            value: category.score,
          ),
    ]),
    empty: 'No object above the score threshold.',
  ),
  ImageClassifierResult(:final classifications) => (
    title: 'Classifications',
    count: _plural(
      classifications.firstOrNull?.categories.length ?? 0,
      'class',
      'classes',
    ),
    items: [
      for (final category
          in classifications.firstOrNull?.categories ??
              const <MediaPipeCategory>[])
        (
          name: _name(
            category.displayName,
            category.categoryName,
            category.index,
          ),
          value: category.score,
        ),
    ],
    empty: 'No class above the score threshold.',
  ),
  ImageSegmenterResult(:final categoryMask?, :final labels) => (
    title: 'Coverage',
    count: _plural(labels.length, 'class', 'classes'),
    items: _top(_coverage(categoryMask, labels), 4),
    empty: 'Nothing segmented.',
  ),
  ImageSegmenterResult() => (
    title: 'Coverage',
    count: null,
    items: const [],
    empty: 'No category mask returned.',
  ),
  _ => null,
};

double _visibility(List<NormalizedLandmark> landmarks) {
  final seen = [for (final landmark in landmarks) ?landmark.visibility];
  if (seen.isEmpty) return 1;
  return seen.reduce((a, b) => a + b) / seen.length;
}

/// The share of the mask each class covers, sampled every fourth pixel in
/// each direction so a live frame costs little.
List<Score> _coverage(CategoryMask mask, List<String> labels) {
  final counts = <int, int>{};
  var total = 0;
  for (var y = 0; y < mask.height; y += 4) {
    for (var x = 0; x < mask.width; x += 4) {
      final value = mask.categories[y * mask.width + x];
      counts[value] = (counts[value] ?? 0) + 1;
      total++;
    }
  }
  return [
    for (final MapEntry(key: value, value: count) in counts.entries)
      if (value < labels.length) (name: labels[value], value: count / total),
  ];
}

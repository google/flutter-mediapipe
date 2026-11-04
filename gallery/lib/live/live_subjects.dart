import 'package:mediapipe_vision/mediapipe_vision.dart';

/// A landmark in coordinates normalized to the analysed frame.
typedef LivePoint = ({double x, double y});

/// Each subject's landmarks (faces, hands) in a live result, in MediaPipe's
/// order; empty for a result no live demo tracks this way.
List<List<LivePoint>> liveSubjects(Object? result) => switch (result) {
  FaceLandmarkerResult(:final faceLandmarks) => [
    for (final face in faceLandmarks) [for (final p in face) (x: p.x, y: p.y)],
  ],
  HandLandmarkerResult(:final handLandmarks) ||
  GestureRecognizerResult(:final handLandmarks) => [
    for (final hand in handLandmarks) [for (final p in hand) (x: p.x, y: p.y)],
  ],
  PoseLandmarkerResult(:final poseLandmarks) => [
    for (final pose in poseLandmarks) [for (final p in pose) (x: p.x, y: p.y)],
  ],
  HolisticLandmarkerResult(:final poseLandmarks)
      when poseLandmarks.isNotEmpty =>
    [
      [for (final p in poseLandmarks) (x: p.x, y: p.y)],
    ],
  _ => const [],
};

/// Subjects in a live result, and landmarks in the first, without copying.
({int subjects, int points}) liveSubjectCount(Object? result) =>
    switch (result) {
      FaceLandmarkerResult(:final faceLandmarks) => (
        subjects: faceLandmarks.length,
        points: faceLandmarks.firstOrNull?.length ?? 0,
      ),
      HandLandmarkerResult(:final handLandmarks) ||
      GestureRecognizerResult(:final handLandmarks) => (
        subjects: handLandmarks.length,
        points: handLandmarks.firstOrNull?.length ?? 0,
      ),
      PoseLandmarkerResult(:final poseLandmarks) => (
        subjects: poseLandmarks.length,
        points: poseLandmarks.firstOrNull?.length ?? 0,
      ),
      HolisticLandmarkerResult(:final poseLandmarks) => (
        subjects: poseLandmarks.isEmpty ? 0 : 1,
        points: poseLandmarks.length,
      ),
      // A segmented frame counts as one subject when anything is not
      // background.
      ImageSegmenterResult(:final categoryMask?) => (
        subjects: categoryMask.categories.any((c) => c != 0) ? 1 : 0,
        points: 0,
      ),
      _ => (subjects: 0, points: 0),
    };

/// Which landmarks the overlay-alignment oracles compare for one task.
///
/// Across a mirror the IMAGE task does not keep a face's left and right: it
/// labels landmarks by the side of the picture they appear on, so on a
/// preview that mirrors the analysed frame it reports each probe's partner.
/// A hand keeps its landmark numbering when mirrored (only its handedness
/// flips), so every hand probe is its own partner.
final class AlignmentProbes {
  const AlignmentProbes(this.partners);

  /// Probe index to its partner under a mirror.
  final Map<int, int> partners;

  /// Probed landmark indices.
  Iterable<int> get indices => partners.keys;

  /// For the result a live demo produces, or null for one it has no probes for.
  static AlignmentProbes? of(Object? result) => switch (result) {
    FaceLandmarkerResult() => face,
    HandLandmarkerResult() => hand,
    _ => null,
  };

  /// Nose tip, chin, forehead, iris centres, mouth corners, outer eye
  /// corners. Run on the fixture and on its horizontal flip, the official
  /// IMAGE task puts landmark 33 of the flip where the reflection of the
  /// original's 263 is (0.3% of the diagonal), not the original's 33 (17.6%).
  static const face = AlignmentProbes({
    1: 1,
    152: 152,
    10: 10,
    468: 473,
    473: 468,
    61: 291,
    291: 61,
    33: 263,
    263: 33,
  });

  /// Wrist, the five fingertips, and the index and pinky knuckles.
  static const hand = AlignmentProbes({
    0: 0,
    4: 4,
    8: 8,
    12: 12,
    16: 16,
    20: 20,
    5: 5,
    17: 17,
  });
}

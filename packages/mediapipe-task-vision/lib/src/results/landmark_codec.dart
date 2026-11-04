/// One transport layout for landmarks from every platform SDK adapter: each
/// point is five doubles (x, y, z, visibility, presence), NaN for an absent
/// confidence, and `counts` gives the points per subject.
library;

/// A landmark constructor: `NormalizedLandmark.new` or `Landmark.new`.
typedef LandmarkBuilder<T> =
    T Function({
      required double x,
      required double y,
      required double z,
      double? visibility,
      double? presence,
      String? name,
    });

/// Doubles per packed point.
const packedLandmarkStride = 5;

/// Splits [packed] into one landmark list per subject.
List<List<T>> unpackLandmarks<T>(
  List<double> packed,
  List<int> counts,
  LandmarkBuilder<T> point,
) {
  double? optional(double value) => value.isNaN ? null : value;
  if (packed.length != counts.fold(0, (a, b) => a + b) * packedLandmarkStride) {
    throw const FormatException('Packed landmarks do not match their counts.');
  }
  final subjects = <List<T>>[];
  var at = 0;
  for (final count in counts) {
    subjects.add([
      for (var i = 0; i < count; i++, at += packedLandmarkStride)
        point(
          x: packed[at],
          y: packed[at + 1],
          z: packed[at + 2],
          visibility: optional(packed[at + 3]),
          presence: optional(packed[at + 4]),
        ),
    ]);
  }
  return subjects;
}

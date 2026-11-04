/// The strokes Google's stateful Interactive Segmenter takes.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:meta/meta.dart';

/// How a stroke affects the selection, as Google's API names them.
enum BrushMode {
  /// Include the indicated object or area.
  positive(1),

  /// Exclude the indicated area from the selection.
  negative(2),

  /// Select what lies inside the box around the stroke's points. Google's
  /// graph reads a lasso as the bounding box of its points, not as the shape
  /// they trace: an open or closed outline and its two opposite corners give
  /// the same mask, and a tiny box selects only what it covers.
  lasso(3);

  const BrushMode(this.nativeValue);

  /// The value Google's C API takes.
  final int nativeValue;
}

/// One stroke of the history a segmentation request carries: its brush mode
/// and its points, normalized to the input image.
@immutable
final class Stroke {
  /// Owns an unmodifiable copy of [points], at least one in any mode, as
  /// Google's API takes them. A one-point lasso has no area.
  Stroke({
    required this.brushMode,
    required List<NormalizedKeypoint> points,
    this.isCompleted = true,
  }) : points = List.unmodifiable(points) {
    if (points.isEmpty || points.length > 0xffffffff) {
      throw ArgumentError('A stroke requires at least one point.');
    }
    for (final point in points) {
      if (!point.x.isFinite ||
          !point.y.isFinite ||
          point.x < 0 ||
          point.x > 1 ||
          point.y < 0 ||
          point.y > 1) {
        throw ArgumentError('Stroke coordinates must be finite and in [0, 1].');
      }
    }
  }

  /// Whether the stroke includes, excludes or encloses.
  final BrushMode brushMode;

  /// The stroke's points, from 0 to 1 across the image.
  final List<NormalizedKeypoint> points;

  /// False while the pointer is still down, true once it was released.
  /// Include and Exclude strokes read the same either way; Google's CPU
  /// graph reads an unfinished lasso differently from the finished one, so
  /// send a lasso when the pointer lifts, as Google's samples do.
  final bool isCompleted;

  @override
  String toString() =>
      'Stroke(${brushMode.name}, ${points.length} points'
      '${isCompleted ? '' : ', in progress'})';
}

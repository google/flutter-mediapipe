import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'official_mask_references.dart';

/// How a mask compares with Google's: the share of category grid cells with
/// the reference's class, the largest class share difference, and the mean
/// and largest cell difference of each reference confidence grid.
typedef MaskMatch = ({
  double categoryAgreement,
  double shareError,
  Map<int, ({double mean, double max})> confidence,
});

/// Compares [result]'s masks with [reference], each where both exist.
MaskMatch compareMasks(ImageSegmenterResult result, OfficialMasks reference) {
  final category = result.categoryMask;
  final masks = result.confidenceMasks;
  return (
    categoryAgreement: category == null
        ? double.nan
        : categoryGridAgreement(category, reference.category),
    shareError: category == null
        ? double.nan
        : shareError(categoryShares(category), reference.shares),
    confidence: {
      if (masks != null)
        for (final MapEntry(key: index, value: grid)
            in reference.confidence.entries)
          index: confidenceGridError(masks[index], grid),
    },
  );
}

/// The share of [grid]'s cells whose centre pixel has the same class.
double categoryGridAgreement(CategoryMask mask, List<List<int>> grid) {
  final rows = grid.length, columns = grid.first.length;
  var same = 0;
  for (var r = 0; r < rows; r++) {
    final y = (2 * r + 1) * mask.height ~/ (2 * rows);
    for (var c = 0; c < columns; c++) {
      final x = (2 * c + 1) * mask.width ~/ (2 * columns);
      if (mask.categories[y * mask.width + x] == grid[r][c]) same++;
    }
  }
  return same / (rows * columns);
}

/// Each class's share of the mask's pixels.
Map<int, double> categoryShares(CategoryMask mask) {
  final counts = <int, int>{};
  for (final value in mask.categories) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return {
    for (final MapEntry(:key, :value) in counts.entries)
      key: value / mask.categories.length,
  };
}

/// The largest class share difference, counting classes either side lacks.
double shareError(Map<int, double> actual, Map<int, double> expected) {
  var error = 0.0;
  for (final key in {...actual.keys, ...expected.keys}) {
    final difference = ((actual[key] ?? 0) - (expected[key] ?? 0)).abs();
    if (difference > error) error = difference;
  }
  return error;
}

/// Mean and largest difference between [mask]'s cell means and [grid]'s.
({double mean, double max}) confidenceGridError(
  ConfidenceMask mask,
  List<List<double>> grid,
) {
  final rows = grid.length, columns = grid.first.length;
  var total = 0.0, largest = 0.0;
  for (var r = 0; r < rows; r++) {
    final top = r * mask.height ~/ rows, bottom = (r + 1) * mask.height ~/ rows;
    for (var c = 0; c < columns; c++) {
      final left = c * mask.width ~/ columns;
      final right = (c + 1) * mask.width ~/ columns;
      var sum = 0.0;
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          sum += mask.confidence[y * mask.width + x];
        }
      }
      final difference = (sum / ((bottom - top) * (right - left)) - grid[r][c])
          .abs();
      total += difference;
      if (difference > largest) largest = difference;
    }
  }
  return (mean: total / (rows * columns), max: largest);
}

/// Where rotatedImage (sdk_frames.dart) moves the upright pixel (x, y) of a
/// [width] x [height] image when it turns it clockwise by [turn] degrees.
(int, int) turnedPixel(int x, int y, int width, int height, int turn) =>
    switch (turn) {
      90 => (height - 1 - y, x),
      180 => (width - 1 - x, height - 1 - y),
      270 => (y, width - 1 - x),
      _ => (x, y),
    };

/// The mask comparisons below sample every fourth pixel in each direction.
const _step = 4;

/// The share of [upright]'s sampled pixels whose class [turned] repeats where
/// rotatedImage moved them by [turn] degrees.
double turnedCategoryAgreement(
  CategoryMask upright,
  CategoryMask turned,
  int turn,
) {
  var same = 0, total = 0;
  for (var y = 0; y < upright.height; y += _step) {
    for (var x = 0; x < upright.width; x += _step) {
      final (tx, ty) = turnedPixel(x, y, upright.width, upright.height, turn);
      if (upright.categories[y * upright.width + x] ==
          turned.categories[ty * turned.width + tx]) {
        same++;
      }
      total++;
    }
  }
  return same / total;
}

/// The mean confidence difference between [upright] and [turned] at the
/// sampled pixels rotatedImage moved by [turn] degrees.
double turnedConfidenceError(
  ConfidenceMask upright,
  ConfidenceMask turned,
  int turn,
) {
  var error = 0.0;
  var total = 0;
  for (var y = 0; y < upright.height; y += _step) {
    for (var x = 0; x < upright.width; x += _step) {
      final (tx, ty) = turnedPixel(x, y, upright.width, upright.height, turn);
      error +=
          (upright.confidence[y * upright.width + x] -
                  turned.confidence[ty * turned.width + tx])
              .abs();
      total++;
    }
  }
  return error / total;
}

/// The share of [stretched]'s sampled pixels whose class [upright] has at the
/// same relative position.
///
/// Google's Image Segmenter answers a rotated input with the upright mask
/// resized to the input's dimensions, not turned back (upstream-issues.md
/// UP-017), so this is how a rotated result matches the upright one.
double stretchedCategoryAgreement(
  CategoryMask upright,
  CategoryMask stretched,
) {
  var same = 0, total = 0;
  for (var y = 0; y < stretched.height; y += _step) {
    final uy = y * upright.height ~/ stretched.height;
    for (var x = 0; x < stretched.width; x += _step) {
      final ux = x * upright.width ~/ stretched.width;
      if (upright.categories[uy * upright.width + ux] ==
          stretched.categories[y * stretched.width + x]) {
        same++;
      }
      total++;
    }
  }
  return same / total;
}

/// The mean confidence difference measured as [stretchedCategoryAgreement].
double stretchedConfidenceError(
  ConfidenceMask upright,
  ConfidenceMask stretched,
) {
  var error = 0.0;
  var total = 0;
  for (var y = 0; y < stretched.height; y += _step) {
    final uy = y * upright.height ~/ stretched.height;
    for (var x = 0; x < stretched.width; x += _step) {
      final ux = x * upright.width ~/ stretched.width;
      error +=
          (upright.confidence[uy * upright.width + ux] -
                  stretched.confidence[y * stretched.width + x])
              .abs();
      total++;
    }
  }
  return error / total;
}

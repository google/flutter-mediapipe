/// The value types every family's results are made of, named after Google's
/// containers and identical on every platform.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// One classification: Google's `Category`, under the package's name because
/// Flutter's foundation library already exports a `Category`.
@immutable
final class MediaPipeCategory {
  /// Copies a category; [index] is -1 when the model reports none.
  const MediaPipeCategory({
    required this.index,
    required this.score,
    this.categoryName,
    this.displayName,
  });

  /// Index in the model's category list, or -1 when unspecified.
  final int index;

  /// The model's unmodified score.
  final double score;

  /// The category's label from the model metadata, if any.
  final String? categoryName;

  /// The localized display label, if any.
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is MediaPipeCategory &&
      other.index == index &&
      other.score == score &&
      other.categoryName == categoryName &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(index, score, categoryName, displayName);

  @override
  String toString() =>
      'MediaPipeCategory(index: $index, score: $score, '
      'categoryName: $categoryName, displayName: $displayName)';
}

/// The categories one classifier head produced, best first.
@immutable
final class Classifications {
  /// Owns an unmodifiable copy of [categories].
  Classifications({
    required List<MediaPipeCategory> categories,
    required this.headIndex,
    this.headName,
  }) : categories = List.unmodifiable(categories);

  /// Categories in the runtime's order.
  final List<MediaPipeCategory> categories;

  /// The model output head these categories came from.
  final int headIndex;

  /// The head's name from the model metadata, if any.
  final String? headName;

  @override
  String toString() =>
      'Classifications(headIndex: $headIndex, headName: $headName, '
      'categories: $categories)';
}

/// One embedding head's vector: floats, or bytes when quantized.
@immutable
final class Embedding {
  /// Owns an unmodifiable copy of exactly one representation.
  Embedding({
    Float32List? floatEmbedding,
    Uint8List? quantizedEmbedding,
    required this.headIndex,
    this.headName,
  }) : floatEmbedding = floatEmbedding == null
           ? null
           : Float32List.fromList(floatEmbedding).asUnmodifiableView(),
       quantizedEmbedding = quantizedEmbedding == null
           ? null
           : Uint8List.fromList(quantizedEmbedding).asUnmodifiableView() {
    if ((floatEmbedding == null) == (quantizedEmbedding == null)) {
      throw ArgumentError('Supply exactly one embedding representation.');
    }
  }

  /// The vector, or null when the embedder was asked to quantize.
  final Float32List? floatEmbedding;

  /// Scalar-quantized bytes encoding signed 8-bit values, or null for a
  /// float vector.
  final Uint8List? quantizedEmbedding;

  /// The model output head this vector came from.
  final int headIndex;

  /// The head's name from the model metadata, if any.
  final String? headName;

  /// The vector's dimensions.
  int get length => floatEmbedding?.length ?? quantizedEmbedding!.length;

  @override
  String toString() =>
      'Embedding(headIndex: $headIndex, headName: $headName, '
      '${floatEmbedding == null ? 'quantized' : 'float'} x $length)';
}

/// Cosine similarity of two embeddings of the same representation and size,
/// computed in Dart so every platform gives the same answer. Quantized bytes
/// are read as signed 8-bit values, as Google's APIs do.
double cosineSimilarity(Embedding first, Embedding second) {
  final floating = first.floatEmbedding != null;
  if (floating != (second.floatEmbedding != null)) {
    throw ArgumentError('Embedding representations must match.');
  }
  final left = floating
      ? first.floatEmbedding!
      : [for (final v in first.quantizedEmbedding!) v.toSigned(8).toDouble()];
  final right = floating
      ? second.floatEmbedding!
      : [for (final v in second.quantizedEmbedding!) v.toSigned(8).toDouble()];
  if (left.isEmpty || left.length != right.length) {
    throw ArgumentError('Embedding dimensions must be nonzero and equal.');
  }
  var dot = 0.0;
  var normLeft = 0.0;
  var normRight = 0.0;
  for (var i = 0; i < left.length; i++) {
    if (!left[i].isFinite || !right[i].isFinite) {
      throw ArgumentError('Embeddings must contain finite values.');
    }
    dot += left[i] * right[i];
    normLeft += left[i] * left[i];
    normRight += right[i] * right[i];
  }
  if (normLeft == 0 ||
      normRight == 0 ||
      !dot.isFinite ||
      !normLeft.isFinite ||
      !normRight.isFinite) {
    throw ArgumentError('Embedding norms must be finite and nonzero.');
  }
  return (dot / math.sqrt(normLeft) / math.sqrt(normRight)).clamp(-1.0, 1.0);
}

/// A box in pixels of the input image, as Google's C API reports it, not
/// clipped to the image.
@immutable
final class BoundingBox {
  /// Creates a box from its edges.
  const BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Left edge in pixels.
  final int left;

  /// Top edge in pixels.
  final int top;

  /// Right edge in pixels.
  final int right;

  /// Bottom edge in pixels.
  final int bottom;

  /// Width in pixels.
  int get width => right - left;

  /// Height in pixels.
  int get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      other is BoundingBox &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() =>
      'BoundingBox(left: $left, top: $top, right: $right, bottom: $bottom)';
}

/// A point normalized to the input image: 0 to 1 across its width and height.
@immutable
final class NormalizedKeypoint {
  /// Creates a point; coordinates are not clamped.
  const NormalizedKeypoint({
    required this.x,
    required this.y,
    this.label,
    this.score,
  });

  /// Horizontal coordinate divided by the image width.
  final double x;

  /// Vertical coordinate divided by the image height.
  final double y;

  /// The model's label for this point, if any.
  final String? label;

  /// The point's own confidence, if the model reports one.
  final double? score;

  @override
  bool operator ==(Object other) =>
      other is NormalizedKeypoint &&
      other.x == x &&
      other.y == y &&
      other.label == label &&
      other.score == score;

  @override
  int get hashCode => Object.hash(x, y, label, score);

  @override
  String toString() =>
      'NormalizedKeypoint(x: $x, y: $y, label: $label, score: $score)';
}

/// One detected object or face: its box, categories and, for models that
/// report them, keypoints.
@immutable
final class Detection {
  /// Owns unmodifiable copies of the lists.
  Detection({
    required this.boundingBox,
    required List<MediaPipeCategory> categories,
    List<NormalizedKeypoint> keypoints = const [],
  }) : categories = List.unmodifiable(categories),
       keypoints = List.unmodifiable(keypoints);

  /// Pixel coordinates in the input image.
  final BoundingBox boundingBox;

  /// Categories in the runtime's order, best first.
  final List<MediaPipeCategory> categories;

  /// Keypoints in the model's order, empty when it reports none.
  final List<NormalizedKeypoint> keypoints;

  @override
  String toString() =>
      'Detection(boundingBox: $boundingBox, categories: $categories, '
      'keypoints: $keypoints)';
}

/// A landmark in image space: [x] and [y] relative to the image's width and
/// height, [z] scaled like [x] with smaller values closer to the camera.
@immutable
final class NormalizedLandmark {
  /// Copies a landmark without clamping.
  const NormalizedLandmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility,
    this.presence,
    this.name,
  });

  /// Horizontal coordinate relative to the image width; may leave `[0, 1]`.
  final double x;

  /// Vertical coordinate relative to the image height; may leave `[0, 1]`.
  final double y;

  /// Relative depth, scaled like [x]; not meters.
  final double z;

  /// Confidence that the landmark is visible, when the model reports it.
  final double? visibility;

  /// Confidence that the landmark is present, when the model reports it.
  final double? presence;

  /// The model's name for this landmark, if any.
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is NormalizedLandmark &&
      other.x == x &&
      other.y == y &&
      other.z == z &&
      other.visibility == visibility &&
      other.presence == presence &&
      other.name == name;

  @override
  int get hashCode => Object.hash(x, y, z, visibility, presence, name);

  @override
  String toString() =>
      'NormalizedLandmark(x: $x, y: $y, z: $z, visibility: $visibility, '
      'presence: $presence, name: $name)';
}

/// A landmark in world space, in meters from the subject's center.
@immutable
final class Landmark {
  /// Copies a landmark.
  const Landmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility,
    this.presence,
    this.name,
  });

  /// Horizontal coordinate in meters.
  final double x;

  /// Vertical coordinate in meters.
  final double y;

  /// Depth in meters.
  final double z;

  /// Confidence that the landmark is visible, when the model reports it.
  final double? visibility;

  /// Confidence that the landmark is present, when the model reports it.
  final double? presence;

  /// The model's name for this landmark, if any.
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is Landmark &&
      other.x == x &&
      other.y == y &&
      other.z == z &&
      other.visibility == visibility &&
      other.presence == presence &&
      other.name == name;

  @override
  int get hashCode => Object.hash(x, y, z, visibility, presence, name);

  @override
  String toString() =>
      'Landmark(x: $x, y: $y, z: $z, visibility: $visibility, '
      'presence: $presence, name: $name)';
}

/// A matrix in column-major order, as Google's C API lays it out.
@immutable
final class Matrix {
  /// Owns an unmodifiable copy of [data], which holds [rows] times [columns]
  /// values.
  Matrix({
    required this.rows,
    required this.columns,
    required List<double> data,
  }) : data = List.unmodifiable(data) {
    if (rows <= 0 || columns <= 0 || data.length != rows * columns) {
      throw ArgumentError('Matrix dimensions must match the data.');
    }
  }

  /// Row count; 4 for a facial transformation matrix.
  final int rows;

  /// Column count; 4 for a facial transformation matrix.
  final int columns;

  /// Column-major values: element (row, column) is `data[column * rows + row]`.
  final List<double> data;

  /// Reads one element with bounds checking.
  double at(int row, int column) {
    RangeError.checkValueInInterval(row, 0, rows - 1, 'row');
    RangeError.checkValueInInterval(column, 0, columns - 1, 'column');
    return data[column * rows + row];
  }

  @override
  String toString() => 'Matrix($rows x $columns, $data)';
}

/// Per-pixel confidences in row-major input-image coordinates, from 0 to 1,
/// owned by the result and valid after the task is disposed.
@immutable
final class ConfidenceMask {
  /// Owns an unmodifiable copy of [confidence], [width] times [height]
  /// values, without thresholding.
  ConfidenceMask({
    required this.width,
    required this.height,
    required Float32List confidence,
  }) : confidence = Float32List.fromList(confidence).asUnmodifiableView() {
    if (width <= 0 || height <= 0 || confidence.length != width * height) {
      throw ArgumentError('Mask dimensions must match the confidence buffer.');
    }
  }

  /// Mask width, the input image's.
  final int width;

  /// Mask height, the input image's.
  final int height;

  /// Confidences indexed by `y * width + x`.
  final Float32List confidence;

  @override
  String toString() => 'ConfidenceMask($width x $height)';
}

/// The winning category index per pixel, in row-major input-image
/// coordinates, owned by the result and valid after the task is disposed.
@immutable
final class CategoryMask {
  /// Owns an unmodifiable copy of [categories], [width] times [height]
  /// indices into the model's label list.
  CategoryMask({
    required this.width,
    required this.height,
    required Uint8List categories,
  }) : categories = Uint8List.fromList(categories).asUnmodifiableView() {
    if (width <= 0 || height <= 0 || categories.length != width * height) {
      throw ArgumentError('Mask dimensions must match the category buffer.');
    }
  }

  /// Mask width, the input image's.
  final int width;

  /// Mask height, the input image's.
  final int height;

  /// Category indices indexed by `y * width + x`.
  final Uint8List categories;

  @override
  String toString() => 'CategoryMask($width x $height)';
}

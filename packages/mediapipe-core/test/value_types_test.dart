import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';
import 'package:test/test.dart';

void main() {
  test('small value types compare by value', () {
    const category = MediaPipeCategory(index: 1, score: 0.5, categoryName: 'a');
    expect(
      category,
      const MediaPipeCategory(index: 1, score: 0.5, categoryName: 'a'),
    );
    expect(category.hashCode, category.hashCode);
    expect(category, isNot(const MediaPipeCategory(index: 2, score: 0.5)));
    expect(
      const BoundingBox(left: 1, top: 2, right: 11, bottom: 22),
      const BoundingBox(left: 1, top: 2, right: 11, bottom: 22),
    );
    expect(const BoundingBox(left: 1, top: 2, right: 11, bottom: 22).width, 10);
    expect(
      const NormalizedLandmark(x: 0.1, y: 0.2, z: 0.3),
      const NormalizedLandmark(x: 0.1, y: 0.2, z: 0.3),
    );
    expect(
      const NormalizedLandmark(x: 0.1, y: 0.2, z: 0.3),
      isNot(const Landmark(x: 0.1, y: 0.2, z: 0.3)),
    );
    expect(
      const NormalizedKeypoint(x: 0.5, y: 0.5, label: 'nose').toString(),
      contains('nose'),
    );
  });

  test('results own unmodifiable copies', () {
    final categories = [const MediaPipeCategory(index: 0, score: 1)];
    final head = Classifications(categories: categories, headIndex: 0);
    categories.clear();
    expect(head.categories, hasLength(1));
    expect(() => head.categories.clear(), throwsUnsupportedError);
    final detection = Detection(
      boundingBox: const BoundingBox(left: 0, top: 0, right: 1, bottom: 1),
      categories: head.categories,
    );
    expect(detection.keypoints, isEmpty);
    expect(() => detection.categories.clear(), throwsUnsupportedError);
    final mask = ConfidenceMask(
      width: 2,
      height: 1,
      confidence: Float32List.fromList([0.25, 0.75]),
    );
    expect(() => mask.confidence[0] = 0, throwsUnsupportedError);
    expect(
      () => CategoryMask(width: 2, height: 2, categories: Uint8List(3)),
      throwsArgumentError,
    );
    final matrix = Matrix(rows: 2, columns: 2, data: const [1, 2, 3, 4]);
    expect(matrix.at(1, 0), 2);
    expect(matrix.at(0, 1), 3);
    expect(() => matrix.at(2, 0), throwsRangeError);
    expect(
      () => Matrix(rows: 2, columns: 2, data: const [1]),
      throwsArgumentError,
    );
  });

  test('embeddings hold exactly one representation', () {
    final floats = Embedding(
      floatEmbedding: Float32List.fromList([1, 0]),
      headIndex: 0,
    );
    expect(floats.length, 2);
    expect(floats.quantizedEmbedding, isNull);
    expect(
      () => Embedding(headIndex: 0),
      throwsArgumentError,
      reason: 'neither representation',
    );
    expect(
      () => Embedding(
        floatEmbedding: Float32List(1),
        quantizedEmbedding: Uint8List(1),
        headIndex: 0,
      ),
      throwsArgumentError,
      reason: 'both representations',
    );
  });

  test('cosine similarity is the same for floats and signed bytes', () {
    Embedding floats(List<double> values) =>
        Embedding(floatEmbedding: Float32List.fromList(values), headIndex: 0);
    Embedding bytes(List<int> values) => Embedding(
      quantizedEmbedding: Uint8List.fromList([
        for (final v in values) v.toUnsigned(8),
      ]),
      headIndex: 0,
    );
    expect(cosineSimilarity(floats([1, 0]), floats([1, 0])), closeTo(1, 1e-9));
    expect(cosineSimilarity(floats([1, 0]), floats([0, 1])), closeTo(0, 1e-9));
    expect(
      cosineSimilarity(floats([1, 0]), floats([-1, 0])),
      closeTo(-1, 1e-9),
    );
    // -3 is stored as the byte 253 and read back as signed.
    expect(cosineSimilarity(bytes([3, 4]), bytes([-3, -4])), closeTo(-1, 1e-9));
    expect(
      () => cosineSimilarity(floats([1]), bytes([1])),
      throwsArgumentError,
    );
    expect(
      () => cosineSimilarity(floats([1]), floats([1, 2])),
      throwsArgumentError,
    );
    expect(
      () => cosineSimilarity(floats([0, 0]), floats([1, 0])),
      throwsArgumentError,
    );
    expect(
      () => cosineSimilarity(floats([double.nan]), floats([1])),
      throwsArgumentError,
    );
  });
}

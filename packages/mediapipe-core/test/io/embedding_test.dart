// mediapipe-core/test/embedding_test.dart
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_core/src/io/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as bindings;

void main() {
  group('Native embeddings should', () {});

  group('Embedding fakes should', () {
    test('store values as floats', () {
      final embedding = Embedding.float(
        Float32List.fromList([0.1, 0.2, 0.3]),
        headIndex: 99,
        headName: 'Embedding',
      );

      expect(embedding.quantizedEmbedding, isNull);
      expect(embedding.headIndex, 99);
      expect(embedding.headName, 'Embedding');
      expect(embedding.isFloat, isTrue);
      expect(embedding.isQuantized, isFalse);
      expect(embedding.floatEmbedding!.length, 3);
      expect(embedding.floatEmbedding![0], closeTo(0.1, 0.0001));
      expect(embedding.floatEmbedding![1], closeTo(0.2, 0.0001));
      expect(embedding.floatEmbedding![2], closeTo(0.3, 0.0001));
    });

    test('store values as quantized', () {
      final embedding = Embedding.quantized(
        Uint8List.fromList([2, 0, 3, 1]),
        headIndex: 99,
        headName: 'Embedding',
      );

      expect(embedding.floatEmbedding, isNull);
      expect(embedding.headIndex, 99);
      expect(embedding.headName, 'Embedding');
      expect(embedding.isFloat, isFalse);
      expect(embedding.isQuantized, isTrue);
      expect(embedding.quantizedEmbedding!.length, 4);
      expect(embedding.quantizedEmbedding![0], 2);
      expect(embedding.quantizedEmbedding![1], 0);
      expect(embedding.quantizedEmbedding![2], 3);
      expect(embedding.quantizedEmbedding![3], 1);
    });
  });
}

// extension DartEmbedding on Embedding {
//   static Embedding direct({
//     Pointer<Float>? floats,
//     Pointer<Char>? quantized,
//     required int length,
//     required int headIndex,
//     required String headName,
//   }) {
//     assert(
//       (floats == null) != (quantized == null),
//       'Must pass exactly 1 of `floats` and `quantized`.',
//     );
//     final ptr = malloc<bindings.Embedding>();
//     if (floats != null) {
//       ptr.ref.float_embedding = floats;
//     }
//     if (quantized != null) {
//       ptr.ref.quantized_embedding = quantized;
//     }
//     ptr.ref.values_count = length;
//     ptr.ref.head_index = headIndex;
//     ptr.ref.head_name = headName.copyToNative();
//     return Embedding(ptr);
//   }
// }

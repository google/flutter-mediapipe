// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/src/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as bindings;

void main() {
  group('Embeddings should', () {
    test('store values as floats', () {
      final nativeFloats = malloc<Float>(3);
      nativeFloats[0] = 0.1;
      nativeFloats[1] = 0.2;
      nativeFloats[2] = 0.3;
      final embedding = DartEmbedding.direct(
        floats: nativeFloats,
        length: 3,
        headIndex: 99,
        headName: 'Embedding',
      );

      expect(embedding.quantizedEmbedding, isNull);
      expect(embedding.headIndex, 99);
      expect(embedding.headName, 'Embedding');
      expect(embedding.type, EmbeddingType.float);
      expect(embedding.floatEmbedding!.length, 3);
      expect(embedding.floatEmbedding![0], closeTo(0.1, 0.0001));
      expect(embedding.floatEmbedding![1], closeTo(0.2, 0.0001));
      expect(embedding.floatEmbedding![2], closeTo(0.3, 0.0001));
    });

    test('store values as quantized', () {
      final embedding = DartEmbedding.direct(
        quantized: Uint8List.fromList([2, 0, 3, 1]).copyToNative(),
        length: 4,
        headIndex: 99,
        headName: 'Embedding',
      );

      expect(embedding.floatEmbedding, isNull);
      expect(embedding.headIndex, 99);
      expect(embedding.headName, 'Embedding');
      expect(embedding.type, EmbeddingType.quantized);
      expect(embedding.quantizedEmbedding!.length, 4);
      expect(embedding.quantizedEmbedding![0], 2);
      expect(embedding.quantizedEmbedding![1], 0);
      expect(embedding.quantizedEmbedding![2], 3);
      expect(embedding.quantizedEmbedding![3], 1);
    });
  });
}

extension DartEmbedding on Embedding {
  static Embedding direct({
    Pointer<Float>? floats,
    Pointer<Char>? quantized,
    required int length,
    required int headIndex,
    required String headName,
  }) {
    assert(
      (floats == null) != (quantized == null),
      'Must pass exactly 1 of `floats` and `quantized`.',
    );
    final ptr = malloc<bindings.Embedding>();
    if (floats != null) {
      ptr.ref.float_embedding = floats;
    }
    if (quantized != null) {
      ptr.ref.quantized_embedding = quantized;
    }
    ptr.ref.values_count = length;
    ptr.ref.head_index = headIndex;
    ptr.ref.head_name = headName.copyToNative();
    return Embedding(ptr);
  }
}

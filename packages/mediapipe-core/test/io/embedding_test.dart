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
  group('Native embeddings should', () {
    test('represent a float embedding pointer correctly', () {
      final ptr = malloc<bindings.Embedding>();
      ptr.ref.float_embedding = Float32List.fromList([0.1, 0.2]).copyToNative();
      ptr.ref.values_count = 2;
      ptr.ref.head_index = 2394723;
      ptr.ref.head_name = 'Head Name'.copyToNative();

      final embedding = Embedding.native(ptr);
      expect(embedding.type, equals(EmbeddingType.float));
      expect(embedding.length, 2);
      expect(embedding.floatEmbedding!.length, 2);
      expect(embedding.floatEmbedding![0], closeTo(0.1, 0.0001));
      expect(embedding.floatEmbedding![1], closeTo(0.2, 0.0001));
      expect(embedding.headIndex, 2394723);
      expect(embedding.headName, 'Head Name');
    });

    test('represent a quantized embedding pointer correctly', () {
      final ptr = malloc<bindings.Embedding>();
      ptr.ref.quantized_embedding =
          Uint8List.fromList([3, 2, 1]).copyToNative();
      ptr.ref.values_count = 3;
      ptr.ref.head_index = 999;
      ptr.ref.head_name = 'Tail Name'.copyToNative();

      final embedding = Embedding.native(ptr);
      expect(embedding.type, equals(EmbeddingType.quantized));
      expect(embedding.quantizedEmbedding!.length, 3);
      expect(embedding.quantizedEmbedding![0], 3);
      expect(embedding.quantizedEmbedding![1], 2);
      expect(embedding.quantizedEmbedding![2], 1);
      expect(embedding.headIndex, 999);
      expect(embedding.headName, 'Tail Name');
    });
  });

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

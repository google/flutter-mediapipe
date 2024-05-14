// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/src/io/test_utils.dart';
import 'package:mediapipe_text/io.dart';
import 'package:mediapipe_core/src/io/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as core_bindings;
import 'package:mediapipe_text/src/io/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;
import 'package:test/test.dart';

void main() {
  group('TextEmbedderResult.native should', () {
    test('load an empty object', () {
      final Pointer<bindings.TextEmbedderResult> ptr =
          calloc<bindings.TextEmbedderResult>();
      // These fields are provided by the real MediaPipe implementation, but
      // Dart ignores them because they are meaningless in context of text tasks
      ptr.ref.embeddings_count = 0;
      ptr.ref.has_timestamp_ms = false;

      final result = TextEmbedderResult.native(ptr);
      expect(result.embeddings, isEmpty);
    });

    test('load a hydrated object', () {
      final Pointer<bindings.TextEmbedderResult> resultPtr =
          calloc<bindings.TextEmbedderResult>();

      final embeddingsPtr = calloc<core_bindings.Embedding>(2);
      populateEmbedding(embeddingsPtr[0], length: 50);
      populateEmbedding(embeddingsPtr[1], length: 25);

      resultPtr.ref.embeddings_count = 2;
      resultPtr.ref.embeddings = embeddingsPtr;
      resultPtr.ref.has_timestamp_ms = false;

      final result = TextEmbedderResult.native(resultPtr);
      expect(result.embeddings, hasLength(2));
      final embedding = result.embeddings.take(1).toList().first;
      expect(embedding.type, EmbeddingType.float);
      expect(embedding.length, 50);
      final embedding2 = result.embeddings.skip(1).take(1).toList().last;
      expect(embedding2.type, EmbeddingType.float);
      expect(embedding2.length, 25);
    }, timeout: const Timeout(Duration(milliseconds: 10)));
  });
}

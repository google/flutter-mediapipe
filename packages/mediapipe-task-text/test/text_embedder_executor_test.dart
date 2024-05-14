// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// `native-assets` tag allows test runs to opt in or out of running integration
// tests via `flutter test -x native-assets` or `flutter test -t native-assets`
@Tags(['native-assets'])

import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/io.dart';
import 'package:test/test.dart';

void main() {
  final pathToModel = path.joinAll([
    io.Directory.current.absolute.path,
    'example/assets/universal_sentence_encoder.tflite',
  ]);
  final modelBytes = io.File(pathToModel).readAsBytesSync();

  group('TextEmbedderExecutor should', () {
    test('run a task', () {
      final executor = TextEmbedderExecutor(
        TextEmbedderOptions.fromAssetBuffer(modelBytes),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      expect(result.embeddings, isNotEmpty);
      result.dispose();
      executor.dispose();
    });

    test('run multiple tasks', () {
      final executor = TextEmbedderExecutor(
        TextEmbedderOptions.fromAssetBuffer(modelBytes),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      expect(result.embeddings, isNotEmpty);
      final TextEmbedderResult result2 = executor.embed('Hello, world!');
      expect(result2.embeddings, isNotEmpty);
      result.dispose();
      result2.dispose();
      executor.dispose();
    });

    test('unpack a result', () {
      final executor = TextEmbedderExecutor(
        TextEmbedderOptions.fromAssetBuffer(modelBytes),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      final embedding = result.embeddings.first;
      expect(embedding.headName, 'response_encoding');
      expect(() => embedding.quantizedEmbedding, throwsA(isA<Exception>()));
      expect(embedding.floatEmbedding, isNotNull);
      expect(embedding.length, 100);
      expect(embedding.type, equals(EmbeddingType.float));
      expect(embedding.floatEmbedding![0], closeTo(1.7475, 0.0001));
      result.dispose();
      executor.dispose();
    });

    test('quantize results when requested', () {
      final executor = TextEmbedderExecutor(
        TextEmbedderOptions.fromAssetBuffer(
          modelBytes,
          embedderOptions: EmbedderOptions(quantize: true),
        ),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      final embedding = result.embeddings.first;
      expect(embedding.headName, 'response_encoding');
      expect(embedding.quantizedEmbedding, isNotNull);
      expect(() => embedding.floatEmbedding, throwsA(isA<Exception>()));
      expect(embedding.quantizedEmbedding![0], 127);
      expect(embedding.length, 100);
      expect(embedding.type, equals(EmbeddingType.quantized));
      result.dispose();
      executor.dispose();
    });

    test('normalize', () {
      final executor = TextEmbedderExecutor(
        TextEmbedderOptions.fromAssetBuffer(
          modelBytes,
          embedderOptions: EmbedderOptions(l2Normalize: true),
        ),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      final embedding = result.embeddings.first;
      expect(embedding.headName, 'response_encoding');
      expect(() => embedding.quantizedEmbedding, throwsA(isA<Exception>()));
      expect(embedding.floatEmbedding, isNotNull);
      expect(embedding.floatEmbedding![0], closeTo(0.1560, 0.0001));
      expect(embedding.length, 100);
      expect(embedding.type, equals(EmbeddingType.float));
      result.dispose();
      executor.dispose();
    });
  });
}

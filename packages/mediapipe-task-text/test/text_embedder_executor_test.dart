// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// `native-assets` tag allows test runs to opt in or out of running integration
// tests via `flutter test -x native-assets` or `flutter test -t native-assets`
@Tags(['native-assets'])
library;

import 'dart:io' as io;

import 'package:path/path.dart' as path;
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_text/src/io/native_text_embedder.dart';
import 'package:test/test.dart';

void main() {
  final pathToModel = path.joinAll([
    io.Directory.current.absolute.path,
    'models/universal_sentence_encoder.tflite',
  ]);
  final modelBytes = io.File(pathToModel).readAsBytesSync();

  group('NativeTextEmbedder should', () {
    test('run a task', () {
      final executor = NativeTextEmbedder(
        TextEmbedderOptions(modelBytes: modelBytes),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      expect(result.embeddings, isNotEmpty);
      executor.close();
    });

    test('run multiple tasks', () {
      final executor = NativeTextEmbedder(
        TextEmbedderOptions(modelBytes: modelBytes),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      expect(result.embeddings, isNotEmpty);
      final TextEmbedderResult result2 = executor.embed('Hello, world!');
      expect(result2.embeddings, isNotEmpty);
      executor.close();
    });

    test('unpack a result', () {
      final executor = NativeTextEmbedder(
        TextEmbedderOptions(modelBytes: modelBytes),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      final embedding = result.embeddings.first;
      expect(embedding.headName, 'response_encoding');
      expect(embedding.quantizedEmbedding, isNull);
      expect(embedding.floatEmbedding, isNotNull);
      expect(embedding.length, 100);
      expect(embedding.floatEmbedding, isNotNull);
      expect(embedding.floatEmbedding![0], closeTo(1.7475, 0.0001));
      executor.close();
    });

    test('quantize results when requested', () {
      final executor = NativeTextEmbedder(
        TextEmbedderOptions(modelBytes: modelBytes, quantize: true),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      final embedding = result.embeddings.first;
      expect(embedding.headName, 'response_encoding');
      expect(embedding.quantizedEmbedding, isNotNull);
      expect(embedding.floatEmbedding, isNull);
      expect(embedding.quantizedEmbedding![0], 127);
      expect(embedding.length, 100);
      expect(embedding.quantizedEmbedding, isNotNull);
      executor.close();
    });

    test('normalize', () {
      final executor = NativeTextEmbedder(
        TextEmbedderOptions(modelBytes: modelBytes, l2Normalize: true),
      );
      final TextEmbedderResult result = executor.embed('Hello, world!');
      final embedding = result.embeddings.first;
      expect(embedding.headName, 'response_encoding');
      expect(embedding.quantizedEmbedding, isNull);
      expect(embedding.floatEmbedding, isNotNull);
      expect(embedding.floatEmbedding![0], closeTo(0.1560, 0.0001));
      expect(embedding.length, 100);
      expect(embedding.floatEmbedding, isNotNull);
      executor.close();
    });
  });
}

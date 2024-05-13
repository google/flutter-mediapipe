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
    'example/assets/bert_classifier.tflite',
  ]);
  final modelBytes = io.File(pathToModel).readAsBytesSync();

  group('TextClassifierExecutor should', () {
    test('run a task', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(modelBytes),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      expect(result.classifications, isNotEmpty);
      executor.dispose();
    });

    test('run multiple tasks', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(modelBytes),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      expect(result.classifications, isNotEmpty);
      final TextClassifierResult result2 = executor.classify('Hello, world!');
      expect(result2.classifications, isNotEmpty);
      executor.dispose();
    });

    test('unpack a result', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(modelBytes),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      final classifications = result.classifications.first;
      expect(classifications.headName, equals('probability'));
      expect(classifications.categories, hasLength(2));
      expect(classifications.categories.first.categoryName, equals('positive'));
      expect(classifications.categories.first.score, closeTo(0.9919, 0.0009));
      expect(classifications.categories.last.categoryName, equals('negative'));
      expect(classifications.categories.last.score, closeTo(0.00804, 0.0009));
      executor.dispose();
    });

    test('use the denylist', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(
          modelBytes,
          classifierOptions: ClassifierOptions(
            categoryDenylist: ['positive'],
          ),
        ),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      final classifications = result.classifications.first;
      expect(classifications.headName, equals('probability'));
      expect(classifications.categories, hasLength(1));
      expect(classifications.categories.first.categoryName, equals('negative'));
      expect(classifications.categories.first.score, closeTo(0.00804, 0.0009));
      executor.dispose();
    });

    test('use the allowlist', () {
      final executor = TextClassifierExecutor(
        TextClassifierOptions.fromAssetBuffer(
          modelBytes,
          classifierOptions: ClassifierOptions(
            categoryAllowlist: ['positive'],
          ),
        ),
      );
      final TextClassifierResult result = executor.classify('Hello, world!');
      final classifications = result.classifications.first;
      expect(classifications.headName, equals('probability'));
      expect(classifications.categories, hasLength(1));
      expect(classifications.categories.first.categoryName, equals('positive'));
      expect(classifications.categories.first.score, closeTo(0.9919, 0.0009));
      result.dispose();
      executor.dispose();
    });
  });
}

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
import 'package:mediapipe_text/src/io/native_language_detector.dart';
import 'package:test/test.dart';

void main() {
  final pathToModel = path.joinAll([
    io.Directory.current.absolute.path,
    'models/language_detector.tflite',
  ]);
  final modelBytes = io.File(pathToModel).readAsBytesSync();

  group('NativeLanguageDetector should', () {
    test('run a task', () {
      final executor = NativeLanguageDetector(
        LanguageDetectorOptions(modelBytes: modelBytes),
      );
      final LanguageDetectorResult result = executor.detect('Hello, world!');
      expect(result.predictions, isNotEmpty);
      executor.close();
    });

    test('run multiple tasks', () {
      final executor = NativeLanguageDetector(
        LanguageDetectorOptions(modelBytes: modelBytes),
      );
      final LanguageDetectorResult result = executor.detect('Hello, world!');
      expect(result.predictions, isNotEmpty);
      final LanguageDetectorResult result2 = executor.detect(
        'Hello, world, again!',
      );
      expect(result2.predictions, isNotEmpty);
      executor.close();
    });

    test('unpack a result', () {
      final executor = NativeLanguageDetector(
        LanguageDetectorOptions(modelBytes: modelBytes),
      );
      final LanguageDetectorResult result = executor.detect('Hello, world!');
      final prediction = result.predictions.first;
      expect(prediction.languageCode, equals('en'));
      expect(prediction.probability, greaterThan(0.99));
      executor.close();
    });

    test('unpack a Spanish result', () {
      final executor = NativeLanguageDetector(
        LanguageDetectorOptions(modelBytes: modelBytes),
      );
      final LanguageDetectorResult result = executor.detect('¡Hola, mundo!');
      final prediction = result.predictions.first;
      expect(prediction.languageCode, equals('es'));
      expect(prediction.probability, greaterThan(0.99));
      executor.close();
    });

    test('use the denylist', () {
      final executor = NativeLanguageDetector(
        LanguageDetectorOptions(
          modelBytes: modelBytes,
          categoryDenylist: ['en'],
        ),
      );
      final LanguageDetectorResult result = executor.detect('Hello, world!');
      final prediction = result.predictions.first;
      expect(prediction.languageCode, 'de');
      expect(prediction.probability, closeTo(0.0011, 0.0001));
      executor.close();
    });

    test('use the allowlist', () {
      final executor = NativeLanguageDetector(
        LanguageDetectorOptions(
          modelBytes: modelBytes,
          categoryAllowlist: ['en'],
        ),
      );
      final LanguageDetectorResult result = executor.detect('Hello, world!');
      expect(result.predictions, hasLength(1));
      final prediction = result.predictions.first;
      expect(prediction.languageCode, equals('en'));
      executor.close();
    });
  });
}

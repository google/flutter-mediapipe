// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/io.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;
import 'package:test/test.dart';

void main() {
  group('LanguageDetectorResult.native should', () {
    test('load an empty object', () {
      final Pointer<bindings.LanguageDetectorResult> ptr =
          calloc<bindings.LanguageDetectorResult>();
      // These fields are provided by the real MediaPipe implementation, but
      // Dart ignores them because they are meaningless in context of text tasks
      ptr.ref.predictions_count = 0;

      final result = LanguageDetectorResult.native(ptr);
      expect(result.predictions, isEmpty);
    });

    test('load a hydrated object', () {
      final Pointer<bindings.LanguageDetectorResult> resultPtr =
          calloc<bindings.LanguageDetectorResult>();

      final predictionsPtr = calloc<bindings.LanguageDetectorPrediction>(2);
      predictionsPtr[0].language_code = 'es'.copyToNative();
      predictionsPtr[0].probability = 0.99;
      predictionsPtr[1].language_code = 'en'.copyToNative();
      predictionsPtr[1].probability = 0.01;

      resultPtr.ref.predictions_count = 2;
      resultPtr.ref.predictions = predictionsPtr;

      final result = LanguageDetectorResult.native(resultPtr);
      expect(result.predictions, hasLength(2));
    }, timeout: const Timeout(Duration(milliseconds: 10)));
  });
}

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
  group('TextClassifierResult.native should', () {
    test('load an empty object', () {
      final Pointer<bindings.TextClassifierResult> ptr =
          calloc<bindings.TextClassifierResult>();
      // These fields are provided by the real MediaPipe implementation, but
      // Dart ignores them because they are meaningless in context of text tasks
      ptr.ref.classifications_count = 0;
      ptr.ref.has_timestamp_ms = true;

      final result = TextClassifierResult.native(ptr);
      expect(result.classifications, isEmpty);
    });

    test('load a hydrated object', () {
      final Pointer<bindings.TextClassifierResult> resultPtr =
          calloc<bindings.TextClassifierResult>();

      final classificationsPtr = calloc<core_bindings.Classifications>(2);
      populateClassifications(classificationsPtr[0]);
      populateClassifications(classificationsPtr[1]);

      resultPtr.ref.classifications_count = 2;
      resultPtr.ref.classifications = classificationsPtr;
      resultPtr.ref.has_timestamp_ms = true;
      resultPtr.ref.timestamp_ms = 0;

      final result = TextClassifierResult.native(resultPtr);
      expect(result.classifications, hasLength(2));
    }, timeout: const Timeout(Duration(milliseconds: 10)));
  });
}

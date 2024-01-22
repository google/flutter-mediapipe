import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_core/src/test_utils.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_core/src/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as core_bindings;
import 'package:mediapipe_text/src/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

void main() {
  group('TextClassifierResult.structToDart should', () {
    test('load an empty object', () {
      final Pointer<bindings.TextClassifierResult> struct =
          calloc<bindings.TextClassifierResult>();
      // These fields are provided by the real MediaPipe implementation, but
      // Dart ignores them because they are meaningless in context of text tasks
      struct.ref.classifications_count = 0;
      struct.ref.has_timestamp_ms = true;

      final result = TextClassifierResult.structToDart(struct.ref);
      expect(result.classifications, isEmpty);
    });

    test('load a hydrated object', () {
      final Pointer<bindings.TextClassifierResult> struct =
          calloc<bindings.TextClassifierResult>();

      final classificationsPtr = calloc<core_bindings.Classifications>(2);
      populateClassifications(classificationsPtr[0]);
      populateClassifications(classificationsPtr[1]);

      struct.ref.classifications_count = 2;
      struct.ref.classifications = classificationsPtr;
      struct.ref.has_timestamp_ms = true;
      struct.ref.timestamp_ms = 0;

      final result = TextClassifierResult.structToDart(struct.ref);
      expect(result.classifications, hasLength(2));
    }, timeout: const Timeout(Duration(milliseconds: 10)));
  });
}

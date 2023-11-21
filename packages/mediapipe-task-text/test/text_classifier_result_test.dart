import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_core/src/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as core_bindings;
import 'package:mediapipe_text/src/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

void main() {
  group('TextClassifierResult.structToDart should', () {
    // test('load an empty object', () {
    //   final Pointer<bindings.TextClassifierResult> struct =
    //       calloc<bindings.TextClassifierResult>();
    //   struct.ref.classifications_count = 0;
    //   struct.ref.has_timestamp_ms = false;

    //   final result = TextClassifierResult.structToDart(struct.ref);
    //   expect(result.classifications, isEmpty);
    //   expect(result.timestamp, isNull);
    // });

    test('load a hydrated object', () {
      final Pointer<bindings.TextClassifierResult> struct =
          calloc<bindings.TextClassifierResult>();

      final classifications = <Pointer<core_bindings.Classifications>>[
        buildClassifications(),
        buildClassifications(index: 2),
      ];
      struct.ref.classifications_count = classifications.length;
      struct.ref.classifications = classifications.first;
      struct.ref.has_timestamp_ms = true;
      struct.ref.timestamp_ms = 9999999;

      final result = TextClassifierResult.structToDart(struct.ref);
      // expect(result.classifications, hasLength(2));
      // expect(result.timestamp, isNotNull);
    }, timeout: const Timeout(Duration(milliseconds: 10)));
  });
}

Pointer<core_bindings.Classifications> buildClassifications({
  String categoryName = 'Positive',
  int index = 1,
  double score = 0.9,
}) {
  final classifications = calloc<core_bindings.Classifications>();
  final category = calloc<core_bindings.Category>();
  category.ref.category_name = prepareString(categoryName);
  category.ref.display_name = prepareString(categoryName);
  category.ref.index = index;
  category.ref.score = score;

  classifications.ref.categories = category;
  classifications.ref.categories_count = 1;
  classifications.ref.head_name = prepareString('head');

  return classifications;
}

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_text/src/io/native_text_classifier.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/classic_text_bindings.dart'
    as mp;
import 'package:test/test.dart';

void main() {
  test('copies an empty 1.0.1 classification result', () {
    final result = using(
      (arena) =>
          textClassifierResultFromNative(arena<mp.MpClassificationResult>()),
    );
    expect(result.classifications, isEmpty);
    expect(result.timestampMilliseconds, isNull);
  });
  test('copies nested categories before caller frees native memory', () {
    final result = using((arena) {
      final output = arena<mp.MpClassificationResult>();
      final heads = arena<mp.MpClassifications>();
      final categories = arena<mp.MpCategory>();
      final name = 'positive'.toNativeUtf8(allocator: arena);
      categories.ref
        ..index = 1
        ..score = .75
        ..categoryName = name.cast();
      heads.ref
        ..categories = categories
        ..categoriesCount = 1
        ..headIndex = 2;
      output.ref
        ..classifications = heads
        ..classificationsCount = 1;
      final result = textClassifierResultFromNative(output);
      categories.ref
        ..index = 99
        ..score = 0;
      name.cast<Uint8>().value = 0;
      return result;
    });
    final head = result.classifications.single;
    expect(head.headName, isNull);
    expect(head.headIndex, 2);
    expect(head.categories.single.index, 1);
    expect(head.categories.single.score, .75);
    expect(head.categories.single.categoryName, 'positive');
    expect(head.categories.single.displayName, isNull);
    expect(() => result.classifications.clear(), throwsUnsupportedError);
    expect(() => (head.categories as List).clear(), throwsUnsupportedError);
  });
}

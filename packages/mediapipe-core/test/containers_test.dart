import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/src/test_utils.dart';
import 'package:test/test.dart';
import 'package:mediapipe_core/src/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as core_bindings;

void main() {
  group('Category.structToDart should', () {
    test('load a Category', () {
      final categoryPtr = calloc<core_bindings.Category>();
      populateCategory(categoryPtr.ref);

      final category = Category.structToDart(categoryPtr.ref);
      expect(category.index, 1);
      expect(category.categoryName, 'Positive');
      expect(category.displayName, isNull);
      expect(category.score, closeTo(0.9, 0.0001));
      Category.freeStruct(categoryPtr.ref);
      calloc.free(categoryPtr);
    });

    test('load a Category with a display name', () {
      final categoryPtr = calloc<core_bindings.Category>();
      populateCategory(categoryPtr.ref, displayName: 'v-good');

      final category = Category.structToDart(categoryPtr.ref);
      expect(category.index, 1);
      expect(category.categoryName, 'Positive');
      expect(category.displayName, 'v-good');
      expect(category.score, closeTo(0.9, 0.0001));
      Category.freeStruct(categoryPtr.ref);
      calloc.free(categoryPtr);
    });

    test('load a Category with no names', () {
      final categoryPtr = calloc<core_bindings.Category>();
      populateCategory(categoryPtr.ref, categoryName: null);

      final category = Category.structToDart(categoryPtr.ref);
      expect(category.index, 1);
      expect(category.categoryName, isNull);
      expect(category.displayName, isNull);
      expect(category.score, closeTo(0.9, 0.0001));
      Category.freeStruct(categoryPtr.ref);
      calloc.free(categoryPtr);
    });

    test('should load a list of structs', () {
      final ptrs = calloc<core_bindings.Category>(2);
      populateCategory(ptrs[0]);
      populateCategory(
        ptrs[1],
        categoryName: 'Negative',
        index: 2,
        score: 0.01,
      );
      final categories = Category.structsToDart(ptrs, 2);
      expect(categories, hasLength(2));
      expect(categories[0].categoryName, 'Positive');
      expect(categories[0].index, 1);
      expect(categories[0].score, closeTo(0.9, 0.0001));

      expect(categories[1].categoryName, 'Negative');
      expect(categories[1].index, 2);
      expect(categories[1].score, closeTo(0.01, 0.0001));
    });
  });

  group('Classifications.structToDart should', () {
    test('load a Classifications object', () {
      final classificationsPtr = calloc<core_bindings.Classifications>();
      populateClassifications(classificationsPtr.ref);

      final classifications =
          Classifications.structToDart(classificationsPtr.ref);
      expect(classifications.headIndex, 1);
      expect(classifications.headName, 'Head');
      expect(classifications.categories.length, 2);
      expect(classifications.categories.first.categoryName, 'Positive');
      expect(classifications.categories.last.categoryName, 'Positive');

      Classifications.freeStructs(classificationsPtr, 1);
    });

    test('load a Classifications object with 1 category', () {
      final classificationsPtr = calloc<core_bindings.Classifications>();
      populateClassifications(classificationsPtr.ref, numCategories: 1);

      final classifications =
          Classifications.structToDart(classificationsPtr.ref);
      expect(classifications.headIndex, 1);
      expect(classifications.headName, 'Head');
      expect(classifications.categories.length, 1);
      expect(classifications.categories.first.categoryName, 'Positive');

      Classifications.freeStructs(classificationsPtr, 1);
    });

    test('load a Classifications object with no categories', () {
      final classificationsPtr = calloc<core_bindings.Classifications>();
      populateClassifications(classificationsPtr.ref, numCategories: 0);

      final classifications =
          Classifications.structToDart(classificationsPtr.ref);
      expect(classifications.headIndex, 1);
      expect(classifications.headName, 'Head');
      expect(classifications.categories.length, 0);

      Classifications.freeStructs(classificationsPtr, 1);
    });
  });
}

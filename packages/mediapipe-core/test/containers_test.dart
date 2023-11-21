import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:test/test.dart';
import 'package:mediapipe_core/src/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as core_bindings;

void main() {
  group('Category.structToDart should', () {
    test('load a Category', () {
      final categoryPtr = calloc<core_bindings.Category>();
      populateCategory(category: categoryPtr.ref);

      final category = Category.structToDart(categoryPtr.ref);
      expect(category.index, 1);
      expect(category.categoryName, 'Positive');
      expect(category.displayName, isNull);
      expect(category.score, closeTo(0.9, 0.0001));
      Category.freeStruct(categoryPtr.ref);
      calloc.free(categoryPtr);
    });

    test('load a Category with a display name', () {
      final categoryPtr = createCategory(displayName: 'v-good');

      final category = Category.structToDart(categoryPtr.ref);
      expect(category.index, 1);
      expect(category.categoryName, 'Positive');
      expect(category.displayName, 'v-good');
      expect(category.score, closeTo(0.9, 0.0001));
      Category.freeStruct(categoryPtr.ref);
      calloc.free(categoryPtr);
    });

    test('load a Category with no names', () {
      final categoryPtr = createCategory(categoryName: null);

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
      // final Pointer<core_bindings.Category> ptr = ptrs[0];
      populateCategory(category: ptrs[0]);
      populateCategory(
        category: ptrs[1],
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
}

void populateCategory({
  required core_bindings.Category category,
  int index = 1,
  double score = 0.9,
  String? categoryName = 'Positive',
  String? displayName,
}) {
  category.index = index;
  category.score = score;

  if (categoryName != null) {
    category.category_name = prepareString(categoryName);
  }
  if (displayName != null) {
    category.display_name = prepareString(displayName);
  }
}

import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/src/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as core_bindings;

/// Hydrates a faked [core_bindings.Category] object.
void populateCategory(
  core_bindings.Category category, {
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

/// Hydrates a faked [core_bindings.Classifications] object.
///
/// If [categories] is passed, [numCategories] must indicate its length;
/// otherwise, this function generates [numCategories] faked
/// [core_bindings.Category] objects.
void populateClassifications(
  core_bindings.Classifications classifications, {
  Pointer<core_bindings.Category>? categories,
  int numCategories = 2,
  int headIndex = 1,
  String headName = 'Head',
}) {
  if (isNotNullOrNullPointer(categories)) {
    classifications.categories = categories!;
    classifications.categories_count = numCategories;
  } else {
    final ptrs = calloc<core_bindings.Category>(numCategories);
    int count = 0;
    while (count < numCategories) {
      populateCategory(ptrs[count]);
      count++;
    }
    classifications.categories = ptrs;
    classifications.categories_count = numCategories;
  }
  classifications.head_name = prepareString(headName);
  classifications.head_index = headIndex;
}

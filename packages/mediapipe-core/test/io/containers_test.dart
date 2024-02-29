// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/src/io/mediapipe_core.dart';
import 'package:test/test.dart';
import 'package:mediapipe_core/src/io/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as core_bindings;
import 'package:mediapipe_core/src/io/test_utils.dart';

void main() {
  group('Category.native should', () {
    test('load a Category', () {
      using((arena) {
        final categoryPtr = arena<core_bindings.Category>();
        populateCategory(categoryPtr.ref);

        final category = Category.native(categoryPtr);
        expect(category.index, 1);
        expect(category.categoryName, 'Positive');
        expect(category.displayName, isNull);
        expect(category.score, closeTo(0.9, 0.0001));
      });
    });

    test('load a Category with a display name', () {
      using((arena) {
        final categoryPtr = arena<core_bindings.Category>();
        populateCategory(categoryPtr.ref, displayName: 'v-good');

        final category = Category.native(categoryPtr);
        expect(category.index, 1);
        expect(category.categoryName, 'Positive');
        expect(category.displayName, 'v-good');
        expect(category.score, closeTo(0.9, 0.0001));
      });
    });

    test('load a Category with no names', () {
      using((arena) {
        final categoryPtr = arena<core_bindings.Category>();
        populateCategory(categoryPtr.ref, categoryName: null);

        final category = Category.native(categoryPtr);
        expect(category.index, 1);
        expect(category.categoryName, isNull);
        expect(category.displayName, isNull);
        expect(category.score, closeTo(0.9, 0.0001));
      });
    });

    test('should load a list of structs', () {
      using((arena) {
        final ptrs = arena<core_bindings.Category>(2);
        populateCategory(ptrs[0]);
        populateCategory(
          ptrs[1],
          categoryName: 'Negative',
          index: 2,
          score: 0.01,
        );
        final categories = Category.fromNativeArray(ptrs, 2);
        expect(categories, hasLength(2));
        expect(categories[0].categoryName, 'Positive');
        expect(categories[0].index, 1);
        expect(categories[0].score, closeTo(0.9, 0.0001));

        expect(categories[1].categoryName, 'Negative');
        expect(categories[1].index, 2);
        expect(categories[1].score, closeTo(0.01, 0.0001));
      });
    });
  });

  group('Classifications.native should', () {
    test('load a Classifications object', () {
      using((arena) {
        final classificationsPtr = arena<core_bindings.Classifications>();
        populateClassifications(classificationsPtr.ref);

        final classifications = Classifications.native(classificationsPtr);
        expect(classifications.headIndex, 1);
        expect(classifications.headName, 'Head');
        expect(classifications.categories.length, 2);
        expect(classifications.categories.first.categoryName, 'Positive');
        expect(classifications.categories.last.categoryName, 'Positive');
      });
    });

    test('load a Classifications object with 1 category', () {
      using((arena) {
        final classificationsPtr = calloc<core_bindings.Classifications>();
        populateClassifications(classificationsPtr.ref, numCategories: 1);

        final classifications = Classifications.native(classificationsPtr);
        expect(classifications.headIndex, 1);
        expect(classifications.headName, 'Head');
        expect(classifications.categories.length, 1);
        expect(classifications.categories.first.categoryName, 'Positive');
      });
    });

    test('load a Classifications object with no categories', () {
      using((arena) {
        final classificationsPtr = arena<core_bindings.Classifications>();
        populateClassifications(classificationsPtr.ref, numCategories: 0);

        final classifications = Classifications.native(classificationsPtr);
        expect(classifications.headIndex, 1);
        expect(classifications.headName, 'Head');
        expect(classifications.categories.length, 0);
      });
    });
  });
}

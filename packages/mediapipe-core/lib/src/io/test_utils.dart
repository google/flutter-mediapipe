// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'package:mediapipe_core/src/io/mediapipe_core.dart';
import 'package:mediapipe_core/src/io/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
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
    category.category_name = categoryName.copyToNative();
  }
  if (displayName != null) {
    category.display_name = displayName.copyToNative();
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
  if (categories.isNotNullAndIsNotNullPointer) {
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
  classifications.head_name = headName.copyToNative();
  classifications.head_index = headIndex;
}

/// Hydrates a faked [core_bindings.Embedding] object.
void populateEmbedding(
  core_bindings.Embedding embedding, {
  bool quantize = false,
  bool l2Normalize = false,
  int length = 100,
  String headName = 'response_encoding',
  int headIndex = 1,
}) {
  embedding.values_count = length;
  embedding.head_name = headName.copyToNative();
  embedding.head_index = headIndex;

  Random rnd = Random();

  if (quantize) {
    embedding.quantized_embedding = Uint8List.fromList(
      _genInts(length, rnd: rnd).toList(),
    ).copyToNative();
  } else {
    embedding.float_embedding = Float32List.fromList(
      _genFloats(length, l2Normalize: l2Normalize, rnd: rnd).toList(),
    ).copyToNative();
  }
}

Iterable<int> _genInts(int count, {required Random rnd}) sync* {
  int index = 0;
  while (index < count) {
    yield rnd.nextInt(127);
    index++;
  }
}

Iterable<double> _genFloats(int count,
    {required bool l2Normalize, required Random rnd}) sync* {
  int index = 0;
  while (index < count) {
    final dbl = rnd.nextDouble();
    yield l2Normalize ? dbl : dbl * 127;
    index++;
  }
}

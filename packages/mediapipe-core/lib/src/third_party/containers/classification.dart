// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import '../mediapipe/generated/mediapipe_common_bindings.dart' as bindings;

/// Dart representation of MediaPipe's "Category" concept.
///
/// Category is a util class, that contains a [categoryName], its [displayName],
/// a float value as [score], and the [index] of the label in the corresponding
/// label file. Typically it's used as result of classification or detection
/// tasks.
///
/// See more:
///  * [MediaPipe's Category documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/components/containers/Category)
class Category {
  /// Generative constructor that creates a [Category] instance.
  const Category({
    required this.index,
    required this.score,
    required this.categoryName,
    required this.displayName,
  });

  /// The index of the label in the corresponding label file.
  final int index;

  /// The probability score of this label category.
  final double score;

  /// The label of this category object.
  final String? categoryName;

  /// The display name of the label, which may be translated for different locales.
  final String? displayName;

  /// Accepts a pointer to a list of structs, and a count representing the length
  /// of the list, and returns a list of pure-Dart [Category] instances.
  static List<Category> structsToDart(
    Pointer<bindings.Category> structs,
    int count,
  ) {
    final categories = <Category>[];
    for (int i = 0; i < count; i++) {
      categories.add(structToDart(structs[i]));
    }
    return categories;
  }

  /// Accepts a pointer to a single struct and returns a pure-Dart [Category] instance.
  static Category structToDart(bindings.Category struct) {
    return Category(
      index: struct.index,
      score: struct.score,
      categoryName: toDartString(struct.category_name),
      displayName: toDartString(struct.display_name),
    );
  }

  /// Releases all C memory associated with a list of [bindings.Category] pointers.
  /// This method is important to call after calling [Category.structsToDart].
  static void freeStructs(Pointer<bindings.Category> structs, int count) {
    int index = 0;
    while (index < count) {
      bindings.Category obj = structs[index];
      Category.freeStruct(obj);
      index++;
    }
    calloc.free(structs);
  }

  /// Releases the string fields associated with a single [bindings.Category]
  /// struct.
  static void freeStruct(bindings.Category struct) {
    calloc.free(struct.category_name);
    calloc.free(struct.display_name);
  }

  @override
  String toString() => 'Category(index=$index, score=$score, '
      'categoryName=$categoryName, displayName=$displayName)';
}

/// Dart representation of MediaPipe's "Classifications" concept.
///
/// Represents the list of classification for a given classifier head.
/// Typically used as a result for classification tasks.
///
/// See also:
///  * [MediaPipe's Classifications documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/components/containers/Classifications)
class Classifications {
  /// Generative constructor that creates a [Classifications] instance.
  const Classifications({
    required this.categories,
    required this.headIndex,
    required this.headName,
  });

  /// A list of [Category] objects which contain the actual classification
  /// information, including human-readable labels and probability scores.
  final List<Category> categories;

  /// The index of the classifier head these entries refer to.
  final int headIndex;

  /// The optional name of the classifier head, which is the corresponding
  /// tensor metadata name.
  final String? headName;

  /// Accepts a pointer to a list of structs, and a count representing the length
  /// of the list, and returns a list of pure-Dart [Classifications] instances.
  static List<Classifications> structsToDart(
    Pointer<bindings.Classifications> structs,
    int count,
  ) {
    final classifications = <Classifications>[];
    for (int i = 0; i < count; i++) {
      classifications.add(structToDart(structs[i]));
    }
    return classifications;
  }

  /// Accepts a pointer to a single struct and returns a pure-Dart [Classifications]
  /// instance.
  static Classifications structToDart(bindings.Classifications struct) {
    return Classifications(
      categories: Category.structsToDart(
        struct.categories,
        struct.categories_count,
      ),
      headIndex: struct.head_index,
      headName: toDartString(struct.head_name),
    );
  }

  /// Releases all C memory associated with a list of [bindings.Classifications]
  /// pointers. This method is important to call after calling [Classifications.structsToDart]
  /// to convert that C memory into pure-Dart objects.
  static void freeStructs(
    Pointer<bindings.Classifications> structs,
    int count,
  ) {
    int index = 0;
    while (index < count) {
      bindings.Classifications obj = structs[index];
      Category.freeStructs(obj.categories, obj.categories_count);
      calloc.free(obj.head_name);
      index++;
    }
    calloc.free(structs);
  }

  /// Convenience getter for the first [Category] out of the [categories] list.
  Category? get firstCategory =>
      categories.isNotEmpty ? categories.first : null;

  @override
  String toString() {
    final categoryStrings = categories.map((cat) => cat.toString()).join(', ');
    return 'Classification(categories=[$categoryStrings], '
        'headIndex=$headIndex, headName=$headName)';
  }
}

/// Container for classification results across any MediaPipe task.
abstract class ClassifierResult {
  /// Container for classification results across any MediaPipe task.
  const ClassifierResult({
    required this.classifications,
  });

  /// The classification results for each head of the model.
  final List<Classifications> classifications;

  /// Convenience helper for the first [Classifications] object.
  Classifications? get firstClassification =>
      classifications.isNotEmpty ? classifications.first : null;

  @override
  String toString() {
    final classificationStrings =
        classifications.map((cat) => cat.toString()).join(', ');
    return '$runtimeType(classifications=[$classificationStrings])';
  }
}

/// Container for classification results that may describe a slice of time
/// within a larger, streaming data source (.e.g, a video or audio file).
abstract class TimestampedClassifierResult extends ClassifierResult {
  /// Generative constructor.
  const TimestampedClassifierResult({
    required super.classifications,
    this.timestamp,
  });

  /// The optional timestamp (as a [Duration]) of the start of the chunk of data
  /// corresponding to these results.
  ///
  /// This is only used for classification on time series (e.g. audio
  /// classification). In these use cases, the amount of data to process might
  /// exceed the maximum size that the model can process: to solve this, the
  /// input data is split into multiple chunks starting at different timestamps.
  final Duration? timestamp;

  @override
  String toString() {
    final classificationStrings =
        classifications.map((cat) => cat.toString()).join(', ');
    return '$runtimeType(classifications=[$classificationStrings], '
        'timestamp=$timestamp)';
  }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:equatable/equatable.dart';

/// {@template Category}
/// Dart representation of MediaPipe's "Category" concept.
///
/// Category is a util class, that contains a [categoryName], its [displayName],
/// a float value as [score], and the [index] of the label in the corresponding
/// label file. Typically it's used as result of classification or detection
/// tasks.
///
/// See more:
///  * [MediaPipe's Category documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/components/containers/Category)
/// {@endtemplate}
abstract class BaseCategory extends Equatable {
  /// The index of the label in the corresponding label file.
  int get index;

  /// The probability score of this label category.
  double get score;

  /// The label of this category object.
  String? get categoryName;

  /// The display name of the label, which may be translated for different locales.
  String? get displayName;

  @override
  String toString() => 'Category(index=$index, score=$score, '
      'categoryName=$categoryName, displayName=$displayName)';

  @override
  List<Object?> get props => [index, score, categoryName, displayName];
}

/// {@template Classifications}
/// Dart representation of MediaPipe's "Classifications" concept.
///
/// Represents the list of classification for a given classifier head.
/// Typically used as a result for classification tasks.
///
/// See also:
///  * [MediaPipe's Classifications documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/components/containers/Classifications)
/// {@endtemplate}
abstract class BaseClassifications extends Equatable {
  /// A list of [Category] objects which contain the actual classification
  /// information, including human-readable labels and probability scores.
  List<BaseCategory> get categories;

  /// The index of the classifier head these entries refer to.
  int get headIndex;

  /// The optional name of the classifier head, which is the corresponding
  /// tensor metadata name.
  String? get headName;

  /// Convenience getter for the first [Category] out of the [categories] list.
  BaseCategory? get firstCategory =>
      categories.isNotEmpty ? categories.first : null;

  @override
  String toString() {
    final categoryStrings = categories.map((cat) => cat.toString()).join(', ');
    return 'Classification(categories=[$categoryStrings], '
        'headIndex=$headIndex, headName=$headName)';
  }

  @override
  List<Object?> get props => [categories, headIndex, headName];
}

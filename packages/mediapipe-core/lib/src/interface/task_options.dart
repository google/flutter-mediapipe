// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// {@template TaskOptions}
/// Root class for options classes for MediaPipe tasks.
///
/// Implementing classes will contain two [BaseInnerTaskOptions] subclasses,
/// including a descendent of the universal options struct, [IBaseOptions]. The
/// second field will be task-specific.
/// {@endtemplate}
abstract class BaseTaskOptions extends Equatable {
  /// {@macro TaskOptions}
  const BaseTaskOptions();

  /// {@template TaskOptions.baseOptions}
  /// Options class shared by all MediaPipe tasks - namely, how to find and load
  /// the task-specific models at runtime.
  /// {@endtemplate}
  BaseBaseOptions get baseOptions;
}

/// {@template InnerTaskOptions}
/// Parent class for building block options classes which are later grouped
/// together to comprise all relevant options for a specific MediaPipe task.
/// {@endtemplate}
abstract class BaseInnerTaskOptions extends Equatable {
  /// {@macro InnerTaskOptions}
  const BaseInnerTaskOptions();
}

/// Indicates how a [BaseOptions] instance informs surrounding code how to find
/// the MediaPipe model which will fulfill a given task.
enum BaseOptionsType {
  /// Pointer to a MediaPipe model on disk. Not suitable for web.
  path,

  /// Raw MediaPipe model bytes. Suitable for io or web.
  memory
}

/// {@template BaseOptions}
/// Dart representation of MediaPipe's "BaseOptions" concept.
///
/// Used to configure various classifiers by specifying the model they will use
/// for computation.
///
/// See also:
///  * [MediaPipe's BaseOptions documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/core/BaseOptions)
///  * [ClassifierOptions], which is often used in conjunction to specify a
///    classifier's desired behavior.
/// {@endtemplate}
abstract class BaseBaseOptions extends BaseInnerTaskOptions {
  /// {@macro BaseOptions}
  const BaseBaseOptions();

  /// The model asset file contents as bytes;
  Uint8List? get modelAssetBuffer;

  /// Path to the model asset file.
  String? get modelAssetPath;

  /// Flavor of how this [BaseOptions] instance indicates where the rest of the
  /// application should find the desired MediaPipe model.
  BaseOptionsType get type;

  @override
  List<Object?> get props => [
        modelAssetBuffer,
        modelAssetBuffer?.lengthInBytes,
        modelAssetPath,
        type,
      ];
}

/// {@template ClassifierOptions}
/// Dart representation of MediaPipe's "ClassifierOptions" concept.
///
/// Classifier options shared across MediaPipe classification tasks.
///
/// See also:
///  * [MediaPipe's ClassifierOptions documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/components/processors/ClassifierOptions)
///  * [BaseOptions], which is often used in conjunction to specify a
///    classifier's desired behavior.
/// {@endtemplate}
abstract class BaseClassifierOptions extends BaseInnerTaskOptions {
  /// {@macro ClassifierOptions}
  const BaseClassifierOptions();

  /// The locale to use for display names specified through the TFLite Model
  /// Metadata.
  String? get displayNamesLocale;

  /// The maximum number of top-scored classification results to return.
  int? get maxResults;

  /// If set, establishes a minimum `score` and leads to the rejection of any
  /// categories with lower `score` values.
  double? get scoreThreshold;

  /// Allowlist of category names.
  ///
  /// If non-empty, classification results whose category name is not in
  /// this set will be discarded. Duplicate or unknown category names
  /// are ignored. Mutually exclusive with `categoryDenylist`.
  List<String>? get categoryAllowlist;

  /// Denylist of category names.
  ///
  /// If non-empty, classification results whose category name is in this set
  /// will be discarded. Duplicate or unknown category names are ignored.
  /// Mutually exclusive with `categoryAllowList`.
  List<String>? get categoryDenylist;

  @override
  List<Object?> get props => [
        displayNamesLocale,
        maxResults,
        scoreThreshold,
        ...(categoryAllowlist ?? []),
        ...(categoryDenylist ?? []),
      ];
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// {@template BaseOptions}
/// Root class for options classes for MediaPipe tasks.
/// {@endtemplate}
abstract class Options extends Equatable {}

/// {@template TaskOptions}
/// Implementing classes will contain two [BaseInnerTaskOptions] subclasses,
/// including a descendent of the universal options struct, [BaseBaseOptions].
/// The second field will be task-specific.
/// {@endtemplate}
///
/// This implementation is not immutable to track whether `dispose` has been
/// called. All values used by pkg:equatable are in fact immutable.
// ignore: must_be_immutable
abstract class BaseTaskOptions extends Options {
  /// {@macro TaskOptions}
  BaseTaskOptions();

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

/// {@template EmbedderOptions}
/// Dart representation of MediaPipe's "EmbedderOptions" concept.
///
/// Embedder options shared across MediaPipe embedding tasks.
///
/// See also:
///  * [MediaPipe's EmbedderOptions documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/textembedder/TextEmbedder.TextEmbedderOptions)
///  * [BaseOptions], which is often used in conjunction to specify a
///    embedder's desired behavior.
/// {@endtemplate}
abstract class BaseEmbedderOptions extends BaseInnerTaskOptions {
  /// {@macro EmbedderOptions}
  const BaseEmbedderOptions();

  /// Whether to normalize the returned feature vector with L2 norm. Use this
  /// option only if the model does not already contain a native L2_NORMALIZATION
  /// TF Lite Op. In most cases, this is already the case and L2 norm is thus
  /// achieved through TF Lite inference.
  ///
  /// See also:
  ///   * [TutorialsPoint guide on L2 normalization](https://www.tutorialspoint.com/machine_learning_with_python/machine_learning_with_python_ltwo_normalization.htm)
  bool get l2Normalize;

  /// Whether the returned embedding should be quantized to bytes via scalar
  /// quantization. Embeddings are implicitly assumed to be unit-norm and
  /// therefore any dimension is guaranteed to have a value in [-1.0, 1.0]. Use
  /// the l2_normalize option if this is not the case.
  ///
  /// See also:
  ///   * [l2Normalize]
  bool get quantize;

  @override
  List<Object?> get props => [l2Normalize, quantize];
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:ffi/ffi.dart';
import 'ffi_utils.dart';
import 'third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as bindings;

/// Dart representation of MediaPipe's "BaseOptions" concept.
///
/// Used to configure various classifiers by specifying the model they will use
/// for computation.
///
/// See also:
///  * [MediaPipe's BaseOptions documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/core/BaseOptions)
///  * [ClassifierOptions], which is often used in conjunction to specify a
///    classifier's desired behavior.
class BaseOptions extends Equatable {
  /// Generative constructor that creates a [BaseOptions] instance.
  const BaseOptions._({
    this.modelAssetBuffer,
    this.modelAssetPath,
    required _BaseOptionsType type,
  })  : assert(
          !(modelAssetBuffer == null && modelAssetPath == null),
          'You must supply either `modelAssetBuffer` or `modelAssetPath`',
        ),
        assert(
          !(modelAssetBuffer != null && modelAssetPath != null),
          'You must only supply one of `modelAssetBuffer` and `modelAssetPath`',
        ),
        _type = type;

  /// Constructor for [BaseOptions] classes using a file system path.
  ///
  /// In practice, this is unsupported, as assets in Flutter are bundled into
  /// the build output and not available on disk. However, it can potentially
  /// be helpful for testing / development purposes.
  factory BaseOptions.path(String path) => BaseOptions._(
        modelAssetPath: path,
        type: _BaseOptionsType.path,
      );

  /// Constructor for [BaseOptions] classes using an in-memory pointer to the
  /// MediaPipe SDK.
  ///
  /// In practice, this is the only option supported for production builds.
  factory BaseOptions.memory(Uint8List buffer) {
    return BaseOptions._(
      modelAssetBuffer: buffer,
      type: _BaseOptionsType.memory,
    );
  }

  /// The model asset file contents as bytes;
  final Uint8List? modelAssetBuffer;

  /// Path to the model asset file.
  final String? modelAssetPath;

  final _BaseOptionsType _type;

  /// Converts this pure-Dart representation into C-memory suitable for the
  /// MediaPipe SDK to instantiate various classifiers.
  Pointer<bindings.BaseOptions> toStruct() {
    final struct = calloc<bindings.BaseOptions>();

    if (_type == _BaseOptionsType.path) {
      struct.ref.model_asset_path = prepareString(modelAssetPath!);
    }
    if (_type == _BaseOptionsType.memory) {
      struct.ref.model_asset_buffer = prepareUint8List(modelAssetBuffer!);
      struct.ref.model_asset_buffer_count = modelAssetBuffer!.lengthInBytes;
    }
    return struct;
  }

  /// Releases all C memory held by this [bindings.BaseOptions] struct.
  static void freeStruct(bindings.BaseOptions struct) {
    if (struct.model_asset_path.isNotNullPointer) {
      calloc.free(struct.model_asset_path);
    }
    if (struct.model_asset_buffer.isNotNullPointer) {
      calloc.free(struct.model_asset_buffer);
    }
  }

  @override
  List<Object?> get props => [
        modelAssetBuffer,
        modelAssetPath,
        modelAssetBuffer?.lengthInBytes,
      ];
}

enum _BaseOptionsType { path, memory }

/// Dart representation of MediaPipe's "ClassifierOptions" concept.
///
/// Classifier options shared across MediaPipe classification tasks.
///
/// See also:
///  * [MediaPipe's ClassifierOptions documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/components/processors/ClassifierOptions)
///  * [BaseOptions], which is often used in conjunction to specify a
///    classifier's desired behavior.
class ClassifierOptions extends Equatable {
  /// Generative constructor that creates a [ClassifierOptions] instance.
  const ClassifierOptions({
    this.displayNamesLocale,
    this.maxResults,
    this.scoreThreshold,
    this.categoryAllowlist,
    this.categoryDenylist,
  });

  /// The locale to use for display names specified through the TFLite Model
  /// Metadata.
  final String? displayNamesLocale;

  /// The maximum number of top-scored classification results to return.
  final int? maxResults;

  /// If set, establishes a minimum `score` and leads to the rejection of any
  /// categories with lower `score` values.
  final double? scoreThreshold;

  /// Allowlist of category names.
  ///
  /// If non-empty, classification results whose category name is not in
  /// this set will be discarded. Duplicate or unknown category names
  /// are ignored. Mutually exclusive with `categoryDenylist`.
  final List<String>? categoryAllowlist;

  /// Denylist of category names.
  ///
  /// If non-empty, classification results whose category name is in this set
  /// will be discarded. Duplicate or unknown category names are ignored.
  /// Mutually exclusive with `categoryAllowList`.
  final List<String>? categoryDenylist;

  /// Converts this pure-Dart representation into C-memory suitable for the
  /// MediaPipe SDK to instantiate various classifiers.
  Pointer<bindings.ClassifierOptions> toStruct() {
    final struct = calloc<bindings.ClassifierOptions>();
    _setDisplayNamesLocale(struct.ref);
    _setMaxResults(struct.ref);
    _setScoreThreshold(struct.ref);
    _setAllowlist(struct.ref);
    _setDenylist(struct.ref);
    return struct;
  }

  void _setDisplayNamesLocale(bindings.ClassifierOptions struct) {
    if (displayNamesLocale != null) {
      struct.display_names_locale = prepareString(displayNamesLocale!);
    }
  }

  void _setMaxResults(bindings.ClassifierOptions struct) {
    // This value must not be zero, and -1 implies no limit.
    struct.max_results = maxResults ?? -1;
  }

  void _setScoreThreshold(bindings.ClassifierOptions struct) {
    if (scoreThreshold != null) {
      struct.score_threshold = scoreThreshold!;
    }
  }

  void _setAllowlist(bindings.ClassifierOptions struct) {
    if (categoryAllowlist != null) {
      struct.category_allowlist = prepareListOfStrings(categoryAllowlist!);
      struct.category_allowlist_count = categoryAllowlist!.length;
    }
  }

  void _setDenylist(bindings.ClassifierOptions struct) {
    if (categoryDenylist != null) {
      struct.category_denylist = prepareListOfStrings(categoryDenylist!);
      struct.category_denylist_count = categoryDenylist!.length;
    }
  }

  /// Releases all C memory held by this [bindings.ClassifierOptions] struct.
  static void freeStruct(bindings.ClassifierOptions struct) {
    if (struct.display_names_locale.address != 0) {
      calloc.free(struct.display_names_locale);
    }
    if (struct.category_allowlist.address != 0) {
      calloc.free(struct.category_allowlist);
    }
    if (struct.category_denylist.address != 0) {
      calloc.free(struct.category_denylist);
    }
  }

  @override
  List<Object?> get props => [
        displayNamesLocale,
        maxResults,
        scoreThreshold,
        ...(categoryAllowlist ?? []),
        ...(categoryDenylist ?? []),
      ];
}

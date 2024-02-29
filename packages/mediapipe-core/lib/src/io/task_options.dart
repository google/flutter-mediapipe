// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'ffi_utils.dart';
import 'package:mediapipe_core/interface.dart';
import 'third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as bindings;

/// {@template TaskOptions}
/// {@endtemplate}
mixin TaskOptions<T extends Struct> on ITaskOptions {
  /// {@template TaskOptions.copyToNative}
  /// Copies these task options into native memory. Any fields of type
  /// [InnerTaskOptions] should have their `assignToStruct` method called.
  ///
  /// It is the job of [copyToNative] to both create and cache the pointer to
  /// native memory. This means that [copyToNative] can be called more than
  /// once without causing problems other than redundant work.
  /// {@endtemplate}
  Pointer<T> copyToNative() {
    throw UnimplementedError('Must implement `$runtimeType.copyToNative`');
  }

  /// {@template TaskOptions.dispose}
  /// Releases native memory created by [copyToNative].
  /// {@endtemplate}
  void dispose() {
    throw UnimplementedError('Must implement method `$runtimeType.dispose`');
  }
}

/// {@macro InnerTaskOptions}
mixin InnerTaskOptions<T extends Struct> on IInnerTaskOptions {
  /// Assigns all values to an existing struct. This method should be
  /// implemented by all [InnerTaskOptions] types to hydrate a struct, but not
  /// for the creation of that struct. Allocation and management of the actual
  /// structs are handled by [TaskOptions.copyToNative].
  void assignToStruct(T struct) {
    throw UnimplementedError('Must implement $runtimeType.assignToStruct');
  }
}

/// {@macro BaseOptions}
class BaseOptions extends IBaseOptions
    with InnerTaskOptions<bindings.BaseOptions> {
  /// Generative constructor that creates a [BaseOptions] instance.
  const BaseOptions._({
    this.modelAssetBuffer,
    this.modelAssetPath,
    required this.type,
  })  : assert(
          !(modelAssetBuffer == null && modelAssetPath == null),
          'You must supply either `modelAssetBuffer` or `modelAssetPath`',
        ),
        assert(
          !(modelAssetBuffer != null && modelAssetPath != null),
          'You must only supply one of `modelAssetBuffer` and `modelAssetPath`',
        );

  /// {@macro BaseOptions.path}
  factory BaseOptions.path(String path) {
    return BaseOptions._(
      modelAssetPath: path,
      type: BaseOptionsType.path,
    );
  }

  /// {@macro BaseOptions.memory}
  factory BaseOptions.memory(Uint8List buffer) {
    return BaseOptions._(
      modelAssetBuffer: buffer,
      type: BaseOptionsType.memory,
    );
  }

  @override
  final Uint8List? modelAssetBuffer;

  @override
  final String? modelAssetPath;

  @override
  final BaseOptionsType type;

  /// Writes all data to an existing struct which is not owned by this
  /// instance.
  @override
  void assignToStruct(bindings.BaseOptions struct) {
    switch (type) {
      case BaseOptionsType.path:
        {
          struct.model_asset_path = modelAssetPath!.copyToNative();
        }
      case BaseOptionsType.memory:
        {
          struct.model_asset_buffer = modelAssetBuffer!.copyToNative();
          struct.model_asset_buffer_count = modelAssetBuffer!.lengthInBytes;
        }
    }
  }

  /// Releases all C memory held by this [bindings.BaseOptions] struct.
  static void freeStructFields(bindings.BaseOptions struct) {
    if (struct.model_asset_path.isNotNullPointer) {
      calloc.free(struct.model_asset_path);
    }
    if (struct.model_asset_buffer.isNotNullPointer) {
      calloc.free(struct.model_asset_buffer);
    }
  }
}

/// {@macro ClassifierOptions}
class ClassifierOptions extends IClassifierOptions
    with InnerTaskOptions<bindings.ClassifierOptions> {
  /// {@macro ClassifierOptions}
  const ClassifierOptions({
    this.displayNamesLocale,
    this.maxResults,
    this.scoreThreshold,
    this.categoryAllowlist,
    this.categoryDenylist,
  });

  @override
  final String? displayNamesLocale;

  @override
  final int? maxResults;

  @override
  final double? scoreThreshold;

  @override
  final List<String>? categoryAllowlist;

  @override
  final List<String>? categoryDenylist;

  @override
  void assignToStruct(bindings.ClassifierOptions struct) {
    _setDisplayNamesLocale(struct);
    _setMaxResults(struct);
    _setScoreThreshold(struct);
    _setAllowlist(struct);
    _setDenylist(struct);
  }

  void _setDisplayNamesLocale(bindings.ClassifierOptions struct) {
    if (displayNamesLocale != null) {
      struct.display_names_locale = displayNamesLocale!.copyToNative();
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
      struct.category_allowlist = categoryAllowlist!.copyToNative();
      struct.category_allowlist_count = categoryAllowlist!.length;
    }
  }

  void _setDenylist(bindings.ClassifierOptions struct) {
    if (categoryDenylist != null) {
      struct.category_denylist = categoryDenylist!.copyToNative();
      struct.category_denylist_count = categoryDenylist!.length;
    }
  }

  /// Releases all C memory held by this [bindings.ClassifierOptions] struct.
  static void freeStructFields(bindings.ClassifierOptions struct) {
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
}

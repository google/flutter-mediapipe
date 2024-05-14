// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';
import 'package:mediapipe_core/interface.dart';
import 'package:mediapipe_core/src/io/mediapipe_core.dart';
import 'third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as bindings;

/// {@macro Category}
///
/// This io-friendly implementation is not immutable strictly for memoization of
/// computed fields. All values used by pkg:equatable are in fact immutable.
// ignore: must_be_immutable
class Category extends BaseCategory {
  /// {@macro Category.fake}
  Category({
    required int index,
    required double score,
    required String? categoryName,
    required String? displayName,
  })  : _index = index,
        _score = score,
        _categoryName = categoryName,
        _displayName = displayName,
        _pointer = null;

  /// Instantiates a [Category] object as a wrapper around native memory.
  ///
  /// {@template Container.memoryManagement}
  /// This memory is not owned or managed by this class, because all inner
  /// container instances only exist as details within a larger "task result"
  /// object. These task result objects have their own native dispose methods
  /// which cascade down their full tree of structs, releasing everything
  /// properly. Thus, it is not the job of this instance to ever release this
  /// native memory.
  /// {@endtemplate}
  Category.native(this._pointer);

  final Pointer<bindings.Category>? _pointer;

  int? _index;
  @override
  int get index => _index ??= _getIndex();
  int _getIndex() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Category.index');
    }
    return _pointer!.ref.index;
  }

  double? _score;
  @override
  double get score => _score ??= _getScore();
  double _getScore() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Category.score');
    }
    return _pointer!.ref.score;
  }

  String? _categoryName;
  @override
  String? get categoryName => _categoryName ??= _getCategoryName();
  String? _getCategoryName() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Category.categoryName');
    }
    return _pointer!.ref.category_name.isNotNullPointer
        ? _pointer.ref.category_name.toDartString()
        : null;
  }

  String? _displayName;
  @override
  String? get displayName => _displayName ??= _getDisplayName();
  String? _getDisplayName() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Category.displayName');
    }
    return _pointer!.ref.display_name.isNotNullPointer
        ? _pointer.ref.display_name.toDartString()
        : null;
  }

  /// Accepts a pointer to a list of structs, and a count representing the length
  /// of the list, and returns a list of pure-Dart [Category] instances.
  static Iterable<Category> fromNativeArray(
    Pointer<bindings.Category> structs,
    int count,
  ) sync* {
    for (int i = 0; i < count; i++) {
      yield Category.native(structs + i);
    }
  }
}

/// {@macro Classifications}
///
/// This io-friendly implementation is not immutable strictly for memoization of
/// computed fields. All values used by pkg:equatable are in fact immutable.
// ignore: must_be_immutable
class Classifications extends BaseClassifications {
  /// {@macro Classifications.fake}
  Classifications({
    required Iterable<Category> categories,
    required int headIndex,
    required String? headName,
  })  : _categories = categories,
        _headIndex = headIndex,
        _headName = headName,
        _pointer = null;

  /// Instatiates a [Classifications] object as a wrapper around native memory.
  ///
  /// {@macro Container.memoryManagement}
  Classifications.native(this._pointer);

  final Pointer<bindings.Classifications>? _pointer;

  Iterable<Category>? _categories;
  @override
  Iterable<Category> get categories => _categories ??= _getCategories();
  Iterable<Category> _getCategories() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'Could not determine value for Classifications.categories',
      );
    }
    return Category.fromNativeArray(
      _pointer!.ref.categories,
      _pointer.ref.categories_count,
    );
  }

  int? _headIndex;
  @override
  int get headIndex => _headIndex ??= _getHeadIndex();
  int _getHeadIndex() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'Could not determine value for Classifications.headIndex',
      );
    }
    return _pointer!.ref.head_index;
  }

  String? _headName;
  @override
  String? get headName => _headName ??= _getHeadName();
  String? _getHeadName() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Classifications.headName');
    }
    return _pointer!.ref.head_name.isNotNullPointer
        ? _pointer.ref.head_name.toDartString()
        : null;
  }

  /// Accepts a pointer to a list of structs, and a count representing the length
  /// of the list, and returns a list of pure-Dart [Classifications] instances.
  static Iterable<Classifications> fromNativeArray(
    Pointer<bindings.Classifications> structs,
    int count,
  ) sync* {
    for (int i = 0; i < count; i++) {
      yield Classifications.native(structs + i);
    }
  }
}

/// {@macro Embedding}
///
/// This io-friendly implementation is not immutable strictly for memoization of
/// computed fields. All values used by pkg:equatable are in fact immutable.
// ignore: must_be_immutable
class Embedding extends BaseEmbedding {
  /// {@macro Embedding.fakeQuantized}
  Embedding.quantized(
    Uint8List quantizedEmbedding, {
    required int headIndex,
    String? headName,
  })  : _floatEmbedding = null,
        _headIndex = headIndex,
        _headName = headName,
        _quantizedEmbedding = quantizedEmbedding,
        _pointer = null,
        type = EmbeddingType.quantized;

  /// {@macro Embedding.fakeFloat}
  Embedding.float(
    Float32List floatEmbedding, {
    required int headIndex,
    String? headName,
  })  : _floatEmbedding = floatEmbedding,
        _headIndex = headIndex,
        _headName = headName,
        _quantizedEmbedding = null,
        _pointer = null,
        type = EmbeddingType.float;

  /// Instatiates a [Classifications] object as a wrapper around native memory.
  ///
  /// {@macro Container.memoryManagement}
  Embedding.native(this._pointer)
      : type = _pointer!.ref.float_embedding.isNotNullAndIsNotNullPointer
            ? EmbeddingType.float
            : EmbeddingType.quantized;

  final Pointer<bindings.Embedding>? _pointer;

  /// Read-only access to the internal pointer.
  Pointer<bindings.Embedding>? get pointer => _pointer;

  @override
  final EmbeddingType type;

  int? _headIndex;
  @override
  int get headIndex => _headIndex ??= _getHeadIndex();
  int _getHeadIndex() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'Could not determine value for Embedding.headIndex',
      );
    }
    return _pointer!.ref.head_index;
  }

  String? _headName;
  @override
  String? get headName => _headName ??= _getHeadName();
  String? _getHeadName() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Embedding.headName');
    }
    return _pointer!.ref.head_name.isNotNullPointer
        ? _pointer.ref.head_name.toDartString()
        : null;
  }

  Uint8List? _quantizedEmbedding;
  @override
  Uint8List? get quantizedEmbedding =>
      _quantizedEmbedding ??= _getQuantizedEmbedding();
  Uint8List? _getQuantizedEmbedding() {
    if (type != EmbeddingType.quantized) {
      throw Exception(
        'Unexpected access of `quantizedEmbedding` for float embedding',
      );
    }
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'Could not determine value for Embedding.quantizedEmbedding',
      );
    }
    return _pointer!.ref.quantized_embedding.isNotNullPointer
        ? _pointer.ref.quantized_embedding
            .toUint8List(_pointer.ref.values_count)
        : null;
  }

  Float32List? _floatEmbedding;
  @override
  Float32List? get floatEmbedding => _floatEmbedding ??= _getFloatEmbedding();
  Float32List? _getFloatEmbedding() {
    if (type != EmbeddingType.float) {
      throw Exception(
        'Unexpected access of `floatEmbedding` for quantized embedding',
      );
    }
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Embedding.floatEmbedding');
    }
    return _pointer!.ref.float_embedding.isNotNullPointer
        ? _pointer.ref.float_embedding.toFloat32List(_pointer.ref.values_count)
        : null;
  }

  @override
  int get length {
    if (_pointer.isNotNullAndIsNotNullPointer) {
      return _pointer!.ref.values_count;
    }
    return switch (type) {
      EmbeddingType.float => _floatEmbedding!.length,
      EmbeddingType.quantized => _quantizedEmbedding!.length,
    };
  }

  /// Accepts a pointer to a list of structs, and a count representing the length
  /// of the list, and returns a list of pure-Dart [Embedding] instances.
  static Iterable<Embedding> fromNativeArray(
    Pointer<bindings.Embedding> structs,
    int count,
  ) sync* {
    for (int i = 0; i < count; i++) {
      yield Embedding.native(structs + i);
    }
  }
}

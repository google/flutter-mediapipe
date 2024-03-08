// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:mediapipe_core/interface.dart';
import 'package:mediapipe_core/src/io/mediapipe_core.dart';
import 'third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as bindings;

/// {@macro Category}
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

  /// {@template Category.native}
  /// Instatiates a [Category] object as a wrapper around native memory.
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
  String? get categoryName => _categoryName ?? _getCategoryName();
  String? _getCategoryName() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Category.categoryName');
    }
    return _pointer!.ref.category_name.isNotNullPointer
        ? _pointer!.ref.category_name.toDartString()
        : null;
  }

  String? _displayName;
  @override
  String? get displayName => _displayName ?? _getDisplayName();
  String? _getDisplayName() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Category.displayName');
    }
    return _pointer!.ref.display_name.isNotNullPointer
        ? _pointer!.ref.display_name.toDartString()
        : null;
  }

  /// Accepts a pointer to a list of structs, and a count representing the length
  /// of the list, and returns a list of pure-Dart [Category] instances.
  static List<Category> fromNativeArray(
    Pointer<bindings.Category> structs,
    int count,
  ) {
    final categories = <Category>[];
    for (int i = 0; i < count; i++) {
      categories.add(Category.native(structs + i));
    }
    return categories;
  }
}

/// {@macro Classifications}
// ignore: must_be_immutable
base class Classifications extends BaseClassifications {
  /// {@macro Classifications.fake}
  Classifications({
    required List<Category> categories,
    required int headIndex,
    required String? headName,
  })  : _categories = categories,
        _headIndex = headIndex,
        _headName = headName,
        _pointer = null;

  /// {@template Classifications.native}
  /// Instatiates a [Classifications] object as a wrapper around native memory.
  /// {@endtemplate}
  Classifications.native(this._pointer);

  final Pointer<bindings.Classifications>? _pointer;

  List<Category>? _categories;
  @override
  List<Category> get categories => _categories ??= _getCategories();
  List<Category> _getCategories() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'Could not determine value for Classifications.categories',
      );
    }
    return Category.fromNativeArray(
      _pointer!.ref.categories,
      _pointer!.ref.categories_count,
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
  String? get headName => _headName ?? _getHeadName();
  String? _getHeadName() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception('Could not determine value for Classifications.headName');
    }
    return _pointer!.ref.head_name.isNotNullPointer
        ? _pointer!.ref.head_name.toDartString()
        : null;
  }

  /// Accepts a pointer to a list of structs, and a count representing the length
  /// of the list, and returns a list of pure-Dart [Classifications] instances.
  static List<Classifications> fromNativeArray(
    Pointer<bindings.Classifications> structs,
    int count,
  ) {
    final classifications = <Classifications>[];
    for (int i = 0; i < count; i++) {
      classifications.add(Classifications.native(structs + i));
    }
    return classifications;
  }
}

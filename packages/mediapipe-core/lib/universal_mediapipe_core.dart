// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:mediapipe_core/interface.dart';

/// {@macro ClassifierResult}
class ClassifierResult extends IClassifierResult {
  /// {@macro ClassifierResult}
  ClassifierResult();

  /// {@template ClassifierResult.fake}
  /// Instantiates a [ClassifierResult] instance with fake values for testing.
  /// {@endtemplate}
  ClassifierResult.fake({required List<Classifications> classifications});

  @override
  List<IClassifications> get classifications => throw UnimplementedError();

  @override
  void dispose() => throw UnimplementedError();
}

/// {@macro Category}
class Category extends ICategory {
  /// {@template Category.fake}
  /// Initializes a [Category] instance with mock values for testing.
  /// {@endtemplate}
  Category.fake({
    required int index,
    required double score,
    required String? categoryName,
    required String? displayName,
  });

  @override
  String? get categoryName => throw UnimplementedError();

  @override
  String? get displayName => throw UnimplementedError();

  @override
  int get index => throw UnimplementedError();

  @override
  double get score => throw UnimplementedError();
}

/// {@macro Classifications}
class Classifications extends IClassifications {
  /// {@template Classifications.fake}
  /// Instantiates a [Classifications] object with fake values for testing.
  /// {@endtemplate}
  Classifications.fake({
    required List<Category> categories,
    required int headIndex,
    required String? headName,
  }) {
    throw UnimplementedError();
  }

  @override
  List<ICategory> get categories => throw UnimplementedError();

  @override
  int get headIndex => throw UnimplementedError();

  @override
  String? get headName => throw UnimplementedError();
}

/// {@macro BaseOptions}
class BaseOptions extends IBaseOptions {
  /// {@template BaseOptions.path}
  /// Constructor for [BaseOptions] classes using a file system path.
  ///
  /// In practice, this is unsupported, as assets in Flutter are bundled into
  /// the build output and not available on disk. However, it can potentially
  /// be helpful for testing / development purposes.
  /// {@endtemplate}
  BaseOptions.path(String path);

  /// {@template BaseOptions.memory}
  /// Constructor for [BaseOptions] classes using an in-memory pointer to the
  /// MediaPipe SDK.
  ///
  /// In practice, this is the only option supported for production builds.
  /// {@endtemplate}
  BaseOptions.memory(Uint8List buffer);

  @override
  Uint8List? get modelAssetBuffer => throw UnimplementedError();

  @override
  String? get modelAssetPath => throw UnimplementedError();

  @override
  BaseOptionsType get type => throw UnimplementedError();
}

/// {@macro ClassifierOptions}
class ClassifierOptions extends IClassifierOptions {
  /// {@macro ClassifierOptions}
  const ClassifierOptions({
    String? displayNamesLocale,
    int? maxResults,
    double? scoreThreshold,
    List<String>? categoryAllowlist,
    List<String>? categoryDenylist,
  });

  @override
  List<String>? get categoryAllowlist => throw UnimplementedError();

  @override
  List<String>? get categoryDenylist => throw UnimplementedError();

  @override
  String? get displayNamesLocale => throw UnimplementedError();

  @override
  int? get maxResults => throw UnimplementedError();

  @override
  double? get scoreThreshold => throw UnimplementedError();
}

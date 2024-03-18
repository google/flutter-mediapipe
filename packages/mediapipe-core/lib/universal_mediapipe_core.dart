// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:mediapipe_core/interface.dart';

/// {@macro ClassifierResult}
class ClassifierResult extends BaseClassifierResult {
  /// {@template ClassifierResult.fake}
  /// Instantiates a [ClassifierResult] instance with fake values for testing.
  /// {@endtemplate}
  ClassifierResult({required Iterable<Classifications> classifications});

  @override
  Iterable<BaseClassifications> get classifications =>
      throw UnimplementedError();

  @override
  void dispose() => throw UnimplementedError();
}

/// {@macro Category}
class Category extends BaseCategory {
  /// {@template Category.fake}
  /// Initializes a [Category] instance with mock values for testing.
  /// {@endtemplate}
  Category({
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
class Classifications extends BaseClassifications {
  /// {@template Classifications.fake}
  /// Instantiates a [Classifications] object with fake values for testing.
  /// {@endtemplate}
  Classifications({
    required Iterable<Category> categories,
    required int headIndex,
    required String? headName,
  });

  @override
  Iterable<BaseCategory> get categories => throw UnimplementedError();

  @override
  int get headIndex => throw UnimplementedError();

  @override
  String? get headName => throw UnimplementedError();
}

/// {@macro Embedding}
class Embedding extends BaseEmbedding {
  /// {@template Embedding.fakeQuantized}
  /// Instantiates a quantized [Embedding] object with fake values for testing.
  ///
  /// Usage:
  /// ```dart
  /// Embedding.quantized(Uint8List.fromList([1,2,3]), headIndex: 1);
  /// ```
  /// {@endtemplate}
  Embedding.quantized(
    Uint8List quantizedEmbedding, {
    required int headIndex,
    String? headName,
  });

  /// {@template Embedding.fakeFloat}
  /// Instantiates a floating point [Embedding] object with fake values for
  /// testing.
  ///
  /// Usage:
  /// ```dart
  /// Embedding.float(Float32List.fromList([0.1, 0.2, 0.3]), headIndex: 1);
  /// ```
  /// {@endtemplate}
  Embedding.float(
    Float32List floatEmbedding, {
    required int headIndex,
    String? headName,
  });

  @override
  Float32List? get floatEmbedding => throw UnimplementedError();

  @override
  int get headIndex => throw UnimplementedError();

  @override
  String? get headName => throw UnimplementedError();

  @override
  int get length => throw UnimplementedError();

  @override
  Uint8List? get quantizedEmbedding => throw UnimplementedError();

  @override
  EmbeddingType get type => throw UnimplementedError();
}

/// {@macro BaseOptions}
class BaseOptions extends BaseBaseOptions {
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
class ClassifierOptions extends BaseClassifierOptions {
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

/// {@macro EmbedderOptions}
class EmbedderOptions extends BaseEmbedderOptions {
  /// {@macro EmbedderOptions}
  const EmbedderOptions({
    bool l2Normalize = false,
    bool quantize = false,
  });

  @override
  bool get l2Normalize => throw UnimplementedError();

  @override
  bool get quantize => throw UnimplementedError();
}

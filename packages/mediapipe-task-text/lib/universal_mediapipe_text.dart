// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/interface.dart';
export 'package:mediapipe_core/interface.dart' show EmbeddingType;
import 'package:mediapipe_text/interface.dart';

/// {@macro TextClassifier}
class TextClassifier extends BaseTextClassifier {
  /// {@macro TextClassifier}
  TextClassifier(TextClassifierOptions options);

  @override
  Future<TextClassifierResult> classify(String text) =>
      throw UnimplementedError();

  @override
  void dispose() => throw UnimplementedError();
}

/// {@macro TextClassifierOptions}
///
/// This implementation is not immutable to track whether `dispose` has been
/// called. All values used by pkg:equatable are in fact immutable.
// ignore: must_be_immutable
class TextClassifierOptions extends BaseTextClassifierOptions {
  /// {@template TextClassifierOptions.fromAssetPath}
  /// Convenience constructor that looks for the model asset at the given file
  /// system location.
  /// {@endtemplate}
  TextClassifierOptions.fromAssetPath(
    String assetPath, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  });

  /// {@template TextClassifierOptions.fromAssetBuffer}
  /// Convenience constructor that uses a model existing in memory.
  /// {@endtemplate}
  TextClassifierOptions.fromAssetBuffer(
    Uint8List assetBuffer, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  });

  @override
  BaseOptions get baseOptions => throw UnimplementedError();

  @override
  ClassifierOptions get classifierOptions => throw UnimplementedError();
}

/// {@macro TextClassifierResult}
class TextClassifierResult extends BaseTextClassifierResult {
  /// {@template TextClassifierResult.fake}
  /// Instantiates a [TextClassifierResult] with fake data for testing.
  /// {@endtemplate}
  TextClassifierResult({required Iterable<Classifications> classifications});

  @override
  Iterable<Classifications> get classifications => throw UnimplementedError();

  @override
  // ignore: must_call_super
  void dispose() => throw UnimplementedError();
}

/// {@macro TextEmbedder}
class TextEmbedder extends BaseTextEmbedder {
  /// {@macro TextEmbedder}
  TextEmbedder(TextEmbedderOptions options);

  @override
  Future<TextEmbedderResult> embed(String text) => throw UnimplementedError();

  @override
  Future<double> cosineSimilarity(Embedding a, Embedding b) =>
      throw UnimplementedError();

  @override
  void dispose() => throw UnimplementedError();
}

/// {@macro TextEmbedderOptions}
/// This implementation is not immutable to track whether `dispose` has been
/// called. All values used by pkg:equatable are in fact immutable.
// ignore: must_be_immutable
class TextEmbedderOptions extends BaseTextEmbedderOptions {
  /// {@template TextEmbedderOptions.fromAssetPath}
  /// Convenience constructor that looks for the model asset at the given file
  /// system location.
  /// {@endtemplate}
  TextEmbedderOptions.fromAssetPath(
    String assetPath, {
    EmbedderOptions embedderOptions = const EmbedderOptions(),
  });

  /// {@template TextEmbedderOptions.fromAssetBuffer}
  /// Convenience constructor that uses a model existing in memory.
  /// {@endtemplate}
  TextEmbedderOptions.fromAssetBuffer(
    Uint8List assetBuffer, {
    EmbedderOptions embedderOptions = const EmbedderOptions(),
  });

  @override
  BaseOptions get baseOptions => throw UnimplementedError();

  @override
  EmbedderOptions get embedderOptions => throw UnimplementedError();
}

/// {@macro TextEmbedderResult}
class TextEmbedderResult extends BaseEmbedderResult {
  /// {@template TextEmbedderResult.fake}
  /// Instantiates a [TextEmbedderResult] with fake data for testing.
  /// {@endtemplate}
  TextEmbedderResult({required Iterable<Embedding> embeddings});

  @override
  Iterable<Embedding> get embeddings => throw UnimplementedError();

  @override
  // ignore: must_call_super
  void dispose() => throw UnimplementedError();
}

/// {@macro LanguageDetector}
class LanguageDetector extends BaseLanguageDetector {
  /// {@macro LanguageDetector}
  LanguageDetector(LanguageDetectorOptions options);

  @override
  Future<LanguageDetectorResult> detect(String text) =>
      throw UnimplementedError();

  @override
  void dispose() => throw UnimplementedError();
}

/// {@macro LanguageDetectorOptions}
class LanguageDetectorOptions extends BaseLanguageDetectorOptions {
  /// {@template LanguageDetectorOptions.fromAssetPath}
  /// Convenience constructor that looks for the model asset at the given file
  /// system location.
  /// {@endtemplate}
  LanguageDetectorOptions.fromAssetPath(
    String assetPath, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  });

  /// {@template LanguageDetectorOptions.fromAssetBuffer}
  /// Convenience constructor that uses a model existing in memory.
  /// {@endtemplate}
  LanguageDetectorOptions.fromAssetBuffer(
    Uint8List assetBuffer, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  });

  @override
  BaseOptions get baseOptions => throw UnimplementedError();

  @override
  ClassifierOptions get classifierOptions => throw UnimplementedError();
}

/// {@macro LanguageDetectorResult}
class LanguageDetectorResult extends BaseLanguageDetectorResult {
  /// {@template LanguageDetectorResult.fake}
  /// Instantiates a [LanguageDetectorResult] with fake data for testing.
  /// {@endtemplate}
  LanguageDetectorResult(
      {required Iterable<LanguagePrediction> classifications});

  @override
  Iterable<LanguagePrediction> get predictions => throw UnimplementedError();

  @override
  // ignore: must_call_super
  void dispose() => throw UnimplementedError();
}

/// {@macro LanguagePrediction}
class LanguagePrediction extends BaseLanguagePrediction {
  @override
  String get languageCode => throw UnimplementedError();

  @override
  double get probability => throw UnimplementedError();
}

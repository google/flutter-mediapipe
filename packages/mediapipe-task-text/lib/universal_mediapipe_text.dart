// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/interface.dart';
import 'package:mediapipe_text/interface.dart';

/// {@macro TextClassifier}
class TextClassifier extends ITextClassifier {
  /// {@macro TextClassifier}
  TextClassifier(TextClassifierOptions options);

  @override
  Future<TextClassifierResult> classify(String text) =>
      throw UnimplementedError();
}

/// {@macro TextClassifierOptions}
class TextClassifierOptions extends ITextClassifierOptions {
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
class TextClassifierResult extends ITextClassifierResult {
  /// {@template ClassifierResult.fake}
  /// Instantiates a [TextClassifierResult] with fake data for testing.
  /// {@endtemplate}
  TextClassifierResult.fake({required List<Classifications> classifications});

  @override
  List<IClassifications> get classifications => throw UnimplementedError();

  @override
  void dispose() => throw UnimplementedError();
}

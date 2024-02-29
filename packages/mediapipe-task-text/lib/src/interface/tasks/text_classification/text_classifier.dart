// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'text_classification.dart';

/// {@template TextClassifier}
/// Utility to analyze text via MediaPipe's text classification task.
/// {@endtemplate}
abstract class ITextClassifier {
  /// {@template TextClassifier.classify}
  /// Sends a [String] value to MediaPipe for classification.
  /// {@endtemplate}
  Future<ITextClassifierResult> classify(String text);
}

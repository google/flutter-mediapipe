// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/interface.dart';

/// {@template LanguageDetectionResult}
/// Container with results of MediaPipe's language detection task.
///
/// See also:
///  * [MediaPipe's LanguageDetectionResult documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/languagedetector/LanguageDetectorResult)
/// {@endtemplate}
abstract class BaseLanguageDetectorResult extends TaskResult {
  /// {@macro LanguageDetectionResult}
  BaseLanguageDetectorResult();

  /// A list of predictions from the LanguageDetector.
  Iterable<BaseLanguagePrediction> get predictions;
}

/// {@template LanguagePrediction}
/// A language code and its probability. Used as part of the output of
/// a language detector.
/// {@endtemplate}
abstract class BaseLanguagePrediction {
  /// The i18n language / locale code for the prediction.
  String get languageCode;

  /// The probability for the prediction.
  double get probability;
}

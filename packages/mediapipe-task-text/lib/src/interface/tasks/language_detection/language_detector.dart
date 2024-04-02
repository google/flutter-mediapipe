// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'language_detection.dart';

/// {@template LanguageDetector}
/// {@endtemplate}
abstract class BaseLanguageDetector {
  /// {@template LanguageDetector.detect}
  /// Sends a [String] value to MediaPipe for language detection.
  /// {@endtemplate}
  Future<BaseLanguageDetectorResult> detect(String text);

  /// Cleans up all resources.
  void dispose();
}

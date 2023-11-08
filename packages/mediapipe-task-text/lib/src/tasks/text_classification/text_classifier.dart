// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_text/mediapipe_text.dart';

export 'universal_text_classifier.dart'
    if (dart.library.html) 'text_classifier_web.dart'
    if (dart.library.io) 'text_classifier_io.dart';

/// Utility to analyze text via MediaPipe's text classification task.
abstract class BaseTextClassifier {
  /// Generative constructor.
  BaseTextClassifier({required this.options});

  /// Configuration object for tasks completed by this classifier.
  final TextClassifierOptions options;

  /// Sends a `String` value to MediaPipe for classification. Uses an Isolate
  /// on mobile and desktop, and a web worker on web, to add concurrency and avoid
  /// blocking the UI thread while this task completes.
  ///
  /// See also:
  ///  * [classify_sync] for a synchronous alternative
  Future<TextClassifierResult> classify(String text);
}

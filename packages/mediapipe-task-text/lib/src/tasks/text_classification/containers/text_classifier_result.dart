// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/src/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// Container with results of MediaPipe's `classifyText` task.
///
/// See also:
///  * [MediaPipe's textClassifierResult documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/textclassifier/TextClassifierResult)
class TextClassifierResult extends ClassifierResult {
  /// Generative constructor which creates a [TextClassifierResult] instance.
  const TextClassifierResult({required super.classifications});

  /// Factory constructor which converts the C representation of a
  /// [bindings.TextClassifierResult] into a proper Dart [TextClassifierResult].
  factory TextClassifierResult.structToDart(
    bindings.TextClassifierResult struct,
  ) {
    return TextClassifierResult(
      classifications: Classifications.structsToDart(
        struct.classifications,
        struct.classifications_count,
      ),
    );
  }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/src/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// Container with results of MediaPipe's `classifyText` task.
///
/// See also:
///  * [MediaPipe's TextEmbedderResult documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/textembedder/TextEmbedderResult)
class TextEmbedderResult extends EmbeddingResult {
  /// Generative constructor which creates a [TextEmbedderResult] instance.
  const TextEmbedderResult({required super.embeddings});

  /// Factory constructor which converts the C representation of a
  /// [bindings.TextEmbedderResult] into a proper Dart [TextEmbedderResult].
  factory TextEmbedderResult.structToDart(
    bindings.TextEmbedderResult struct,
  ) {
    return TextEmbedderResult(
      embeddings: Embedding.structsToDart(
        struct.embeddings,
        struct.embeddings_count,
      ),
    );
  }
}

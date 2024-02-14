// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/src/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

final _log = Logger('TextEmbedderResult');

/// Container with results of MediaPipe's `embedText` task.
///
/// See also:
///  * [MediaPipe's TextEmbedderResult documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/textembedder/TextEmbedderResult)
class TextEmbedderResult extends EmbeddingResult {
  /// Generative constructor which creates a [TextEmbedderResult] instance.
  TextEmbedderResult(this.pointer);

  /// Pointer to the native memory behind this result.
  final Pointer<bindings.TextEmbedderResult> pointer;
  List<Embedding>? _embeddings;

  @override
  List<Embedding> get embeddings => _embeddings ??= Embedding.fromStructs(
        pointer.ref.embeddings,
        pointer.ref.embeddings_count,
      );

  /// Factory constructor which converts the C representation of a
  /// [bindings.TextEmbedderResult] into a proper Dart [TextEmbedderResult].
  // factory TextEmbedderResult.structToDart(
  //   bindings.TextEmbedderResult struct,
  // ) {
  //   return TextEmbedderResult(
  //     embeddings: Embedding.fromStructs(
  //       struct.embeddings,
  //       struct.embeddings_count,
  //     ),
  //   );
  // }

  @override
  void free() {
    _log.fine('Freeing Pointer<TextEmbedderResult>');
    bindings.text_embedder_close_result(pointer);
  }
}

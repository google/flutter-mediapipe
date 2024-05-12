// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_core/interface.dart';
import '../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@macro TextEmbedderResult}
class TextEmbedderResult extends BaseEmbedderResult with IOTaskResult {
  /// {@macro TextEmbedderResult.fake}
  TextEmbedderResult({required Iterable<Embedding> embeddings})
      : _embeddings = embeddings;

  /// {@template TextEmbedderResult.native}
  /// Initializes a [TextEmbedderResult] instance as a wrapper around native
  /// memory.
  ///
  /// See also:
  ///  * [TextEmbedderExecutor.embed] where this is called.
  /// {@endtemplate}
  TextEmbedderResult.native(this._pointer);

  Pointer<bindings.TextEmbedderResult>? _pointer;

  Iterable<Embedding>? _embeddings;
  @override
  Iterable<Embedding> get embeddings => _embeddings ??= _getEmbeddings();
  Iterable<Embedding> _getEmbeddings() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'No native memory for TextEmbedderResult.embeddings',
      );
    }
    return Embedding.fromNativeArray(
      _pointer!.ref.embeddings,
      _pointer!.ref.embeddings_count,
    );
  }

  @override
  void dispose() {
    assert(() {
      if (isClosed) {
        throw Exception(
          'A TextEmbedderResult was closed after it had already been closed. '
          'TextEmbedderResult objects should only be closed when they are at'
          'their end of life and will never be used again.',
        );
      }
      return true;
    }());
    if (_pointer != null) {
      // Only call the native finalizer if there actually is native memory,
      // because tests may verify that faked results are also closed and calling
      // this method in that scenario would cause a segfault.
      bindings.text_embedder_close_result(_pointer!);
    }
    super.dispose();
  }
}

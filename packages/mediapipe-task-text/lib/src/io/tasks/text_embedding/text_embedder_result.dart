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
  TextEmbedderResult({required Iterable<Embedding> embeddings});

  /// {@template TextEmbedderResult.native}
  /// Initializes a [TextEmbedderResult] instance as a wrapper around native
  /// memory.
  ///
  /// See also:
  ///  * [TextEmbedderExecutor.embed] where this is called.
  /// {@endtemplate}
  TextEmbedderResult.native(this._pointer);

  bool _isClosed = false;

  /// [True] if [dispose] has been called.
  bool get isClosed => _isClosed;

  Pointer<bindings.TextEmbedderResult>? _pointer;

  Iterable<Embedding>? _embeddings;
  @override
  Iterable<Embedding> get embeddings => _embeddings ??= _getEmbeddings();
  Iterable<Embedding> _getEmbeddings() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'No native memory for TextClassifierResult.classifications',
      );
    }
    return Embedding.fromNativeArray(
      _pointer!.ref.embeddings,
      _pointer!.ref.embeddings_count,
    );
  }

  @override
  void dispose() {
    if (_pointer != null && !_isClosed) {
      bindings.text_embedder_close_result(_pointer!);
    }
    _isClosed = true;
  }
}

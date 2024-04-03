// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/io.dart';
// ignore: implementation_imports
import 'package:mediapipe_core/src/io/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as core_bindings;
import 'package:mediapipe_text/src/io/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

final _log = Logger('TextTaskExecutor');

/// Executes MediaPipe's "embedText" task.
///
/// {@macro TaskExecutor}
class TextEmbedderExecutor extends TaskExecutor<bindings.TextEmbedderOptions,
    TextEmbedderOptions, bindings.TextEmbedderResult, TextEmbedderResult> {
  /// {@macro TextEmbedderExecutor}
  TextEmbedderExecutor(super.options);

  @override
  final String taskName = 'TextEmbedding';

  @override
  int closeWorker(Pointer<Void> worker, Pointer<Pointer<Char>> error) {
    final status = bindings.text_embedder_close(worker, error);
    _log.finest('Closed TextEmbedder in native memory with status $status');
    return status;
  }

  @override
  Pointer<bindings.TextEmbedderResult> createResultsPointer() {
    _log.fine('Allocating TextEmbedderResult in native memory');
    final results = calloc<bindings.TextEmbedderResult>();
    _log.finest(
      'Allocated TextEmbedderResult at 0x${results.address.toRadixString(16)}',
    );
    return results;
  }

  @override
  Pointer<Void> createWorker(
    Pointer<bindings.TextEmbedderOptions> options,
    Pointer<Pointer<Char>> error,
  ) {
    _log.fine('Creating TextClassifier in native memory');
    final worker = bindings.text_embedder_create(options, error);
    _log.finest(
      'Created TextClassifier at 0x${worker.address.toRadixString(16)}',
    );
    return worker;
  }

  /// Passes [text] to MediaPipe for conversion into an embedding, yielding a
  /// [TextEmbedderResult] or throwing an exception.
  TextEmbedderResult embed(String text) {
    final resultPtr = createResultsPointer();
    final errorMessageMemory = calloc<Pointer<Char>>();
    final textMemory = text.copyToNative();
    final status = bindings.text_embedder_embed(
      worker,
      textMemory,
      resultPtr,
      errorMessageMemory,
    );
    _log.finest('Embedded with status $status');
    textMemory.free();
    handleErrorMessage(errorMessageMemory, status);
    errorMessageMemory.free(1);
    return TextEmbedderResult.native(resultPtr);
  }

  /// Passes two embeddings to MediaPipe for comparison. Both embeddings should
  /// have been made from embedders with the same configuration for the result
  /// to be meaningful.
  double cosineSimilarity(
    Pointer<core_bindings.Embedding> a,
    Pointer<core_bindings.Embedding> b,
  ) {
    final nativeSimilarity = calloc<Double>();
    final errorMessageMemory = calloc<Pointer<Char>>();
    int status = bindings.text_embedder_cosine_similarity(
      a,
      b,
      nativeSimilarity,
      errorMessageMemory,
    );
    _log.finest('Compared similarity with status $status');
    handleErrorMessage(errorMessageMemory, status);
    errorMessageMemory.free(1);
    final double similarity = nativeSimilarity.value;
    calloc.free(nativeSimilarity);
    return similarity;
  }
}

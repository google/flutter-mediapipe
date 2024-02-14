// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

final _log = Logger('TextTaskExecutor');

/// {@template TextClassifierExecutor}
/// {@endtemplate}
class TextClassifierExecutor2 extends TaskExecutor<
    bindings.TextClassifierOptions,
    TextClassifierOptions,
    bindings.TextClassifierResult,
    TextClassifierResult> {
  /// {@macro TextClassifierExecutor}
  TextClassifierExecutor2(super.options);

  @override
  Pointer<Void> createWorker(
    Pointer<bindings.TextClassifierOptions> options,
    Pointer<Pointer<Char>> error,
  ) {
    _log.info('Creating TextClassifier in native memory');
    return bindings.text_classifier_create(options, error);
  }

  @override
  Pointer<bindings.TextClassifierResult> createResultsPointer() {
    _log.info('Allocating TextClassifierResult in native memory');
    return calloc<bindings.TextClassifierResult>();
  }

  /// Passes [text] to MediaPipe for classification, yielding a
  /// [TextClassifierResult] or throwing an exception.
  TextClassifierResult classify(String text) {
    final resultPtr = createResultsPointer();
    final errorMessageManager = NullTerminatedListOfStringsManager();
    final status = bindings.text_classifier_classify(
      worker,
      text.copyToNative(),
      resultPtr,
      errorMessageManager.memory,
    );
    handleErrorMessage(errorMessageManager, status);
    errorMessageManager.release();
    final result = TextClassifierResult.structToDart(resultPtr.ref);
    bindings.text_classifier_close_result(resultPtr);
    return result;
  }

  @override
  int closeWorker(Pointer<Void> worker, Pointer<Pointer<Char>> error) {
    _log.info('Closing TextClassifier in native memory');
    return bindings.text_classifier_close(worker, error);
  }

  @override
  void freeOptions(Pointer<bindings.TextClassifierOptions> options) {
    _log.info('Releasing TextClassifierOptions in native memory');
    TextClassifierOptions.freeStruct(options);
  }
}

/// {@template TextEmbedderExecutor}
/// {@endtemplate}
class TextEmbedderExecutor extends TaskExecutor<bindings.TextEmbedderOptions,
    TextEmbedderOptions, bindings.TextEmbedderResult, TextEmbedderResult> {
  /// {@macro TextEmbedderExecutor}
  TextEmbedderExecutor(super.options);

  @override
  Pointer<Void> createWorker(
    Pointer<bindings.TextEmbedderOptions> options,
    Pointer<Pointer<Char>> error,
  ) {
    _log.info('Creating TextEmbedder in native memory');
    return bindings.text_embedder_create(options, error);
  }

  @override
  Pointer<bindings.TextEmbedderResult> createResultsPointer() {
    _log.info('Allocating TextEmbedderResult in native memory');
    return calloc<bindings.TextEmbedderResult>();
  }

  /// Passes [text] to MediaPipe for embedding, yielding a
  /// [TextEmbedderResult] or throwing an exception.
  TextEmbedderResult embed(String text) {
    final resultPtr = createResultsPointer();
    final errorMessageManager = NullTerminatedListOfStringsManager();
    final status = bindings.text_embedder_embed(
      worker,
      text.copyToNative(),
      resultPtr,
      errorMessageManager.memory,
    );
    handleErrorMessage(errorMessageManager, status);
    errorMessageManager.release();
    return TextEmbedderResult(resultPtr);
    // TODO: close this later
    // bindings.text_embedder_close_result(resultPtr);
    // return result;
  }

  /// Passes two [Embedding] objects to MediaPipe for comparison, yielding a
  /// [double] or throwing an exception.
  double cosineSimilarity(Embedding a, Embedding b) {
    final similarityMemoryManager = DoubleMemoryManager();
    final errorMessageManager = NullTerminatedListOfStringsManager();
    final status = bindings.text_embedder_cosine_similarity(
      a.ptr,
      b.ptr,
      similarityMemoryManager.memory,
      errorMessageManager.memory,
    );
    handleErrorMessage(errorMessageManager, status);
    final similarity = similarityMemoryManager.memory.value;
    similarityMemoryManager.release();
    return similarity;
  }

  @override
  int closeWorker(Pointer<Void> worker, Pointer<Pointer<Char>> error) {
    _log.info('Closing TextEmbedder in native memory');
    return bindings.text_embedder_close(worker, error);
  }

  @override
  void freeOptions(Pointer<bindings.TextEmbedderOptions> options) {
    _log.info('Releasing TextEmbedderOptions in native memory');
    TextEmbedderOptions.freeStruct(options);
  }
}

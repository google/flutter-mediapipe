// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/io.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

final _log = Logger('TextTaskExecutor');

/// Executes MediaPipe's "classifyText" task.
///
/// {@macro TaskExecutor}
class TextClassifierExecutor extends TaskExecutor<
    bindings.TextClassifierOptions,
    TextClassifierOptions,
    bindings.TextClassifierResult,
    TextClassifierResult> {
  /// {macro TextClassifierExecutor}
  TextClassifierExecutor(super.options);

  @override
  final String taskName = 'TextClassification';

  @override
  Pointer<Void> createWorker(
    Pointer<bindings.TextClassifierOptions> options,
    Pointer<Pointer<Char>> error,
  ) {
    _log.fine('Creating TextClassifier in native memory');
    final worker = bindings.text_classifier_create(options, error);
    _log.finest(
      'Created TextClassifier at 0x${worker.address.toRadixString(16)}',
    );
    return worker;
  }

  @override
  Pointer<bindings.TextClassifierResult> createResultsPointer() {
    _log.fine('Allocating TextClassifierResult in native memory');
    final results = calloc<bindings.TextClassifierResult>();
    _log.finest(
      'Allocated TextClassifierResult at 0x${results.address.toRadixString(16)}',
    );
    return results;
  }

  @override
  int closeWorker(Pointer<Void> worker, Pointer<Pointer<Char>> error) {
    final status = bindings.text_classifier_close(worker, error);
    _log.finest('Closed TextClassifier in native memory with status $status');
    return status;
  }

  /// Passes [text] to MediaPipe for classification, yielding a
  /// [TextClassifierResult] or throwing an exception.
  TextClassifierResult classify(String text) {
    final resultPtr = createResultsPointer();
    final errorMessageMemory = calloc<Pointer<Char>>();
    final textMemory = text.copyToNative();
    final status = bindings.text_classifier_classify(
      worker,
      textMemory,
      resultPtr,
      errorMessageMemory,
    );
    _log.finest('Classified with status $status');
    textMemory.free();
    handleErrorMessage(errorMessageMemory, status);
    errorMessageMemory.free(1);
    return TextClassifierResult.native(resultPtr);
  }
}

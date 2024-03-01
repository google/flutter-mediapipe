// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/io.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

final _log = Logger('TextTaskExecutor');

/// {@template TextClassifierExecutor}
/// Executes MediaPipe's "classifyText" task.
///
/// [TextClassifierExecutor] is separated from [TextClassifier] because
/// MediaPipe has no concept of asynchrony or futures, so this pattern allows a
/// [TextClassifier] to create an executor on a separate isolate, and for
/// Flutter apps to await the results of MediaPipe tasks.
/// {@endtemplate}
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
    final errorMessageManager = NativeStringManager();
    final textMemory = DartStringMemoryManager(text);
    _log.fine('Classifying "${text.shorten()}"');
    final status = bindings.text_classifier_classify(
      worker,
      textMemory.memory,
      resultPtr,
      errorMessageManager.memory,
    );
    _log.finest('Classified with status $status');
    textMemory.free();
    handleErrorMessage(errorMessageManager, status);
    errorMessageManager.free();
    return TextClassifierResult.native(resultPtr);
  }
}

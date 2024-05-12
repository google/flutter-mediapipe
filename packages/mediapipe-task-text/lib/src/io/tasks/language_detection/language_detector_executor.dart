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

final _log = Logger('LanguageDetectorExecutor');

/// Executes MediaPipe's "detect language" task.
///
/// {@macro TaskExecutor}
class LanguageDetectorExecutor extends TaskExecutor<
    bindings.LanguageDetectorOptions,
    LanguageDetectorOptions,
    bindings.LanguageDetectorResult,
    LanguageDetectorResult> {
  /// {@macro LanguageDetectorExecutor}
  LanguageDetectorExecutor(super.options);

  @override
  final String taskName = 'LanguageDetection';

  @override
  Pointer<Void> createWorker(
    Pointer<bindings.LanguageDetectorOptions> options,
    Pointer<Pointer<Char>> error,
  ) {
    _log.fine('Creating LanguageDetector in native memory');
    final worker = bindings.language_detector_create(options, error);
    _log.finest(
      'Created LanguageDetector at 0x${worker.address.toRadixString(16)}',
    );
    return worker;
  }

  @override
  Pointer<bindings.LanguageDetectorResult> createResultsPointer() {
    _log.fine('Allocating LanguageDetectorResult in native memory');
    final results = calloc<bindings.LanguageDetectorResult>();
    _log.finest(
      'Allocated LanguageDetectorResult at 0x${results.address.toRadixString(16)}',
    );
    return results;
  }

  @override
  int closeWorker(Pointer<Void> worker, Pointer<Pointer<Char>> error) {
    final status = bindings.language_detector_close(worker, error);
    _log.finest('Closed LanguageDetector in native memory with status $status');
    return status;
  }

  /// Passes [text] to MediaPipe for classification, yielding a
  /// [LanguageDetectorResult] or throwing an exception.
  LanguageDetectorResult detect(String text) {
    final resultPtr = createResultsPointer();
    final errorMessageMemory = calloc<Pointer<Char>>();
    final textMemory = text.copyToNative();
    final status = bindings.language_detector_detect(
      worker,
      textMemory,
      resultPtr,
      errorMessageMemory,
    );
    _log.finest('Detected with status $status');
    textMemory.free();
    handleErrorMessage(errorMessageMemory, status);
    errorMessageMemory.free(1);
    return LanguageDetectorResult.native(resultPtr);
  }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:logging/logging.dart';

final _log = Logger('TaskExecutor');

/// {@template TaskExecutor}
/// {@endtemplate}
abstract class TaskExecutor<
    NativeOptions extends Struct,
    Options extends TaskOptions<NativeOptions>,
    NativeResult extends Struct,
    Result extends TaskResult> {
  /// {@macro TaskExecutor}
  TaskExecutor(Options options) : _options = options;

  final Options _options;
  Pointer<Void>? _worker;

  /// Idempotent getter which returns a previous worker or creates a new worker
  /// in native memory if there is not yet one.
  Pointer<Void> get worker {
    if (_worker.isNullOrNullPointer) {
      final optionsMemory = TaskOptionsMemoryManager<NativeOptions>(
        options: _options,
        deallocate: freeOptions,
      );
      final errorMessageMemory = NullTerminatedListOfStringsManager();
      _worker = createWorker(
        optionsMemory.memory,
        errorMessageMemory.memory,
      );
      // Release memory needed to create worker.
      handleErrorMessage(errorMessageMemory);
      errorMessageMemory.release();
      optionsMemory.release();
    }
    return _worker!;
  }

  /// Allocates this task's results type in native memory.
  Pointer<NativeResult> createResultsPointer();

  /// Allocates this task's worker type in native memory.
  Pointer<Void> createWorker(
    Pointer<NativeOptions> options,
    Pointer<Pointer<Char>> error,
  );

  /// Releases the worker behind this task.
  int closeWorker(Pointer<Void> worker, Pointer<Pointer<Char>> error);

  /// Releases native memory backing the MediaPipe options that initially
  /// instantiated the worker behind this task.
  void freeOptions(Pointer<NativeOptions> options);

  /// Releases the worker and any remaining resources.
  void dispose() {
    if (_worker != null) {
      _log.info('Closing worker');
      final errorMessageManager = NullTerminatedListOfStringsManager();
      final status = closeWorker(_worker!, errorMessageManager.memory);
      _worker = null;
      handleErrorMessage(errorMessageManager, status);
      errorMessageManager.release();
    }
  }

  /// Throws an exception if the [errorMessage] is non-empty.
  void handleErrorMessage(
    NullTerminatedListOfStringsManager errorMessageManager, [
    int? status,
  ]) {
    if (errorMessageManager.memory.isNotNullPointer &&
        errorMessageManager.memory[0].isNotNullPointer) {
      final dartErrorMessage = errorMessageManager.memory.toDartStrings(1);
      _log.severe('dartErrorMessage: $dartErrorMessage');

      // Release this memory here only if there is an exception, since in that
      // scenario, the calling code is unlikely to get a chance to free the
      // memory.
      errorMessageManager.release();

      // Raise the exception.
      if (status == null) {
        throw Exception('Error: $dartErrorMessage');
      } else {
        throw Exception('Error: Status $status :: $dartErrorMessage');
      }
    }
  }
}

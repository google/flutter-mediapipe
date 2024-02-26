// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:mediapipe_core/io_mediapipe_core.dart';
import 'package:logging/logging.dart';

final _log = Logger('TaskExecutor');

/// {@template TaskExecutor}
/// Instantiates and manages an object which can complete MediaPipe tasks. The
/// object does not exist in Dart memory, but instead in platform-dependent
/// native memory.
///
/// Extending classes should implement [createResultsPointer], [createWorker],
/// [closeWorker], [freeOptions], and any additional task-specific methods.
/// Applications will only call those extra task-specific methods, which will
/// throw an exception on any error communicating with the native workers. It is
/// the job of application code to surround those task-specific methods with
/// try-catch clauses.
/// {@endtemplate}
abstract class TaskExecutor<
    NativeOptions extends Struct,
    Options extends TaskOptions<NativeOptions>,
    NativeResult extends Struct,
    Result extends TaskResult> {
  /// {@macro TaskExecutor}
  TaskExecutor(this.options);

  /// Initialization values for the `worker`.
  final Options options;
  Pointer<Void>? _worker;

  /// Idempotent getter which returns a previous worker or creates a new worker
  /// in native memory if there is not yet one.
  Pointer<Void> get worker {
    if (_worker.isNullOrNullPointer) {
      final errorMessageMemory = NativeStringManager();
      _worker = createWorker(
        options.copyToNative(),
        errorMessageMemory.memory,
      );
      handleErrorMessage(errorMessageMemory);
      errorMessageMemory.free();
      options.free();
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
      final errorMessageManager = NativeStringManager();
      final status = closeWorker(_worker!, errorMessageManager.memory);
      _worker = null;
      handleErrorMessage(errorMessageManager, status);
      errorMessageManager.free();
    }
  }

  /// Throws an exception if [errorMessage] is non-empty.
  void handleErrorMessage(NativeStringManager errorMessage, [int? status]) {
    if (errorMessage.memory.isNotNullPointer &&
        errorMessage.memory[0].isNotNullPointer) {
      final dartErrorMessage = errorMessage.memory.toDartStrings(1);
      _log.severe('dartErrorMessage: $dartErrorMessage');

      // If there is an exception, release this memory the calling code will not
      // get a chance to free the memory.
      errorMessage.free();

      // Raise the exception.
      if (status == null) {
        throw Exception('Error: $dartErrorMessage');
      } else {
        throw Exception('Error: Status $status :: $dartErrorMessage');
      }
    }
  }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/io.dart';
import 'package:logging/logging.dart';

final _log = Logger('TaskExecutor');

/// {@template TaskExecutor}
/// Instantiates and manages an object which can complete MediaPipe tasks. The
/// managed task-completing object does not exist in Dart memory, but instead in
/// platform-dependent native memory.
///
/// Extending classes should implement [createResultsPointer], [createWorker],
/// [closeWorker], and any additional task-specific methods. Applications will
/// only call those extra task-specific methods, which will throw an exception
/// on any error communicating with the native workers. It is the job of
/// application code to surround those task-specific methods with try-catch
/// clauses.
///
/// Executors are separated from their public API counterparts because FFI and
/// MediaPipe have no concept of asynchrony or futures, so this pattern allows a
/// public-facing task handler to create an executor on a separate isolate, and
/// for Flutter apps to await the results of MediaPipe tasks.
/// {@endtemplate}
abstract class TaskExecutor<
    NativeOptions extends Struct,
    Options extends TaskOptions<NativeOptions>,
    NativeResult extends Struct,
    Result extends TaskResult> {
  /// {@macro TaskExecutor}
  TaskExecutor(this.options);

  /// Initialization values for the [worker].
  final Options options;

  /// Inner memoization cache for the [worker].
  Pointer<Void>? _worker;

  /// Debug value for log statements.
  String get taskName;

  /// The native MediaPipe object which will complete this task.
  ///
  /// [worker] is a computed property and will return the same object on
  /// repeated accesses. On the first access, the native [worker] object is
  /// initialized, and this accessor with throw an [Exception] if that process
  /// fails.
  Pointer<Void> get worker {
    if (_worker.isNullOrNullPointer) {
      final errorMessageMemory = calloc<Pointer<Char>>();
      _log.fine('Creating $taskName worker');
      _worker = createWorker(
        options.copyToNative(),
        errorMessageMemory,
      );
      handleErrorMessage(errorMessageMemory);
      errorMessageMemory.free(1);
      options.dispose();
    }
    return _worker!;
  }

  /// Allocates this task's results struct in native memory.
  Pointer<NativeResult> createResultsPointer();

  /// Allocates this task's [worker] object in native memory.
  Pointer<Void> createWorker(
    Pointer<NativeOptions> options,
    Pointer<Pointer<Char>> error,
  );

  /// Releases the [worker] object behind this task.
  int closeWorker(Pointer<Void> worker, Pointer<Pointer<Char>> error);

  /// Releases the [worker] and any remaining resources. After calling [dispose],
  /// re-using the [worker] property will recreate the native object and will
  /// require a second call to [dispose].
  void dispose() {
    if (_worker != null) {
      _log.fine('Closing $taskName worker');
      final errorMessageMemory = calloc<Pointer<Char>>();
      final status = closeWorker(_worker!, errorMessageMemory);
      _worker = null;
      handleErrorMessage(errorMessageMemory, status);
      errorMessageMemory.free(1);
    }
  }

  /// Throws an exception if [errorMessage] is non-empty.
  void handleErrorMessage(Pointer<Pointer<Char>> errorMessage, [int? status]) {
    if (errorMessage.isNotNullPointer && errorMessage[0].isNotNullPointer) {
      final dartErrorMessage = errorMessage.toDartStrings(1);
      _log.severe('$taskName Error: $dartErrorMessage');

      // If there is an exception, release this memory because the calling code
      // will not get a chance to.
      errorMessage.free(1);

      // Raise the exception.
      if (status == null) {
        throw Exception('$taskName Error: $dartErrorMessage');
      } else {
        throw Exception('$taskName Error: Status $status :: $dartErrorMessage');
      }
    }
  }
}

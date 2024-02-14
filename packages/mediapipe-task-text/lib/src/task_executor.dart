// // Copyright 2014 The Flutter Authors. All rights reserved.
// // Use of this source code is governed by a BSD-style license that can be
// // found in the LICENSE file.

// import 'dart:ffi';

// import 'package:ffi/ffi.dart';
// import 'package:logging/logging.dart';
// import 'package:mediapipe_core/mediapipe_core.dart';
// import 'package:mediapipe_text/src/text_task_message.dart';

// final _log = Logger('TaskExecutor');

// /// {@template TaskExecutor}
// /// {@endtemplate}
// class TaskExecutor {
//   /// {@macro TaskExecutor}
//   TaskExecutor({
//     required this.worker,
//     required this.message,
//   });

//   final TextTaskMessage message;
//   final TextTaskWorker worker;

//   Pointer<Void>? _sdkWorkerPointer;
//   Pointer<Struct>? _optionsPtr;
//   Pointer<NativeType>? _resultsPtr;
//   Pointer<Pointer<Char>>? _workerCreationErrorMessage;
//   Pointer<Pointer<Char>>? _executionErrorMessage;

//   /// Performs the actual task.
//   Object performTask() {
//     _createSdkWorker();
//     _execute();
//     return _processResult();
//   }

//   Object _processResult() {
//     final result = message.resultsToDart(_resultsPtr!);
//     message.releaseResults(_resultsPtr!);
//     // closeResults(_resultsPtr!);
//     _resultsPtr = null;
//     return result;
//   }

//   void _execute() {
//     _resultsPtr = message.createResultsPointer();
//     _executionErrorMessage = calloc<Pointer<Char>>();
//     final executionStatus = message.run(
//       _sdkWorkerPointer!,
//       _resultsPtr!,
//       _executionErrorMessage!,
//     );
//     // final int executionStatus = execute(
//     //   errorMessage: _executionErrorMessage!,
//     //   worker: sdkWorkerPointer!,
//     // );
//     _handleErrorMessage(_executionErrorMessage!, executionStatus);
//     _executionErrorMessage = null;
//   }

//   /// Creates the object in C++ memory which will perform the task.
//   void _createSdkWorker() {
//     if (isNotNullOrNullPointer(_sdkWorkerPointer)) return;

//     _workerCreationErrorMessage = calloc<Pointer<Char>>();
//     _sdkWorkerPointer = worker.create(_workerCreationErrorMessage!);

//     _handleErrorMessage(_workerCreationErrorMessage!);
//     _workerCreationErrorMessage = null;
//   }

//   /// Throws an exception if the [errorMessage] is non-empty.
//   ///
//   /// Also frees the memory backing [errorMessage], meaning that calling this
//   /// method completely handles the potential error.
//   void _handleErrorMessage(Pointer<Pointer<Char>> errorMessage, [int? status]) {
//     if (errorMessage.isNotNullPointer && errorMessage[0].isNotNullPointer) {
//       final dartErrorMessage = toDartStrings(errorMessage, 1);
//       _log.severe('dartErrorMessage: $dartErrorMessage');
//       if (status == null) {
//         calloc.free(errorMessage[0]);
//         calloc.free(errorMessage);
//         throw Exception('Error: $dartErrorMessage');
//       } else {
//         throw Exception('Error: Status $status :: $dartErrorMessage');
//       }
//     } else {
//       calloc.free(errorMessage[0]);
//       calloc.free(errorMessage);
//     }
//   }
// }

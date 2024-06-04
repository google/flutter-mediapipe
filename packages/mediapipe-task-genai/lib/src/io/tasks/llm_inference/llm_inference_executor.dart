// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_genai/io.dart';
import 'package:mediapipe_genai/src/io/third_party/mediapipe/generated/mediapipe_genai_bindings.dart'
    as bindings;

final _log = Logger('LlmInferenceExecutor');

/// Shape of the function MediaPipe calls with each additional response chunk
/// from the LLM.
typedef LlmResponseCallback = Void Function(
  Pointer<Void>,
  Pointer<bindings.LlmResponseContext>,
);

/// {@template LlmInferenceExecutor}
/// Executes MediaPipe's inference task.
///
/// {@macro TaskExecutor}
/// {@endtemplate}
class LlmInferenceExecutor extends TaskExecutor<bindings.LlmSessionConfig,
    LlmInferenceOptions, bindings.LlmResponseContext, LlmResponseContext> {
  /// {@macro LlmInferenceExecutor}
  LlmInferenceExecutor(super.options);

  StreamController<LlmResponseContext>? _responseController;

  @override
  String taskName = 'Inference';

  @override
  int closeWorker(Pointer<Void> worker, Pointer<Pointer<Char>> error) {
    bindings.LlmInferenceEngine_Session_Delete(worker);
    return 0;
  }

  @override
  Pointer<bindings.LlmResponseContext> createResultsPointer() =>
      throw UnimplementedError(
        'LlmResponseContext structs should only be created in native code',
      );

  // Holding onto the value created by `createWorker` for disposal.
  Pointer<Void>? _worker;

  @override
  Pointer<Void> createWorker(
    Pointer<bindings.LlmSessionConfig> options,
    Pointer<Pointer<Char>> error,
  ) {
    final worker = malloc<Pointer<bindings.LlmInferenceEngine_Session>>();
    bindings.LlmInferenceEngine_CreateSession(options, worker, error);
    _worker = worker.value.cast<Void>();
    return _worker!;
  }

  ///{@macro generateResponse}
  Stream<LlmResponseContext> generateResponse(String text) {
    assert(() {
      if (_responseController != null) {
        throw Exception(
          'Asked for response before completing response from '
          'previous query, or cancelling previous query.',
        );
      }
      return true;
    }());
    _responseController = StreamController<LlmResponseContext>();
    final textPtr = text.copyToNative();
    final callback = NativeCallable<LlmResponseCallback>.listener(
      (
        Pointer<Void> context,
        Pointer<bindings.LlmResponseContext> responseContext,
      ) {
        if (_responseController == null) {
          // Short-circuit if the caller has cancelled this query before receiving
          // the complete output.
          return;
        }
        // Not often, but also not never, `nullptr` seems to arrive here, which
        // breaks everything if not caught and discarded.
        if (responseContext == nullptr) {
          _log.warning('Discarding unexpected nullptr from PredictAsync');
          return;
        }
        _responseController!.add(
          // Ideally this would pass the raw pointer to the
          // LlmResponseContext.native() constructor and rely on
          // LlmResponseContext.dispose() for cleanup, but passing pointers
          // between threads does not work.
          LlmResponseContext(
            responseArray: responseContext.ref.response_array
                .toDartStrings(responseContext.ref.response_count),
            isDone: responseContext.ref.done,
          ),
        );
        bindings.LlmInferenceEngine_CloseResponseContext(responseContext);
        if (responseContext.ref.done) {
          malloc.free(textPtr);
          _finalizeResponse();
        }
      },
    );
    bindings.LlmInferenceEngine_Session_PredictAsync(
      worker,
      nullptr,
      textPtr,
      callback.nativeFunction,
    );
    return _responseController!.stream;
  }

  /// Terminates an in-progress query, closing down the stream.
  void cancel() {
    assert(() {
      if (_responseController != null) {
        throw Exception('Attempted to cancel a response that is not open.');
      }
      return true;
    }());
    _finalizeResponse();
  }

  void _finalizeResponse() {
    _responseController!.close();
    _responseController = null;
  }

  /// Releases all native resources and closes any open streams.
  void dispose() {
    if (_worker != null) {
      bindings.LlmInferenceEngine_Session_Delete(_worker!);
    }
    if (_responseController != null) {
      _finalizeResponse();
    }
  }

  /// {@macro sizeInTokens}
  int sizeInTokens(String text) {
    final textPtr = text.copyToNative();
    final errorMessageMemory = calloc<Pointer<Char>>();
    final size = bindings.LlmInferenceEngine_Session_SizeInTokens(
      worker,
      textPtr,
      errorMessageMemory,
    );
    handleErrorMessage(errorMessageMemory);
    return size;
  }
}

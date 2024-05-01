// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_genai/interface.dart';
import 'package:mediapipe_genai/io.dart';
import 'package:mediapipe_genai/src/io/third_party/mediapipe/generated/mediapipe_genai_bindings.dart'
    as bindings;

final _log = Logger('LlmInferenceEngine');

/// Shape of the function MediaPipe calls with each additional response chunk
/// from the LLM.
typedef LlmResponseCallback = Void Function(
  Pointer<Void>,
  bindings.LlmResponseContext,
);

/// {@macro LlmInferenceEngine}
class LlmInferenceEngine extends BaseLlmInferenceEngine {
  /// {@macro LlmInferenceEngine}
  LlmInferenceEngine(this._options);

  final LlmInferenceOptions _options;

  StreamController<String>? _responseController;

  Pointer<Pointer<Void>>? __session;

  Pointer<Pointer<Void>> get _session {
    if (__session == null) {
      print('creating __session');
      final nativeOptions = _options.copyToNative();
      __session = malloc<Pointer<bindings.LlmInferenceEngine_Session>>();
      final errorMessageMemory = calloc<Pointer<Char>>();
      print(
          'native model_path :: ${nativeOptions.ref.model_path.toDartString()}');
      print('copied options to native');
      final status = bindings.LlmInferenceEngine_CreateSession(
        nativeOptions,
        __session!,
        errorMessageMemory,
      );
      if (status != 0) {}
      print('__session: $__session');
      // Releases the pointer created by `copyToNative`
      _options.dispose();
      print('disposed of options');
    }
    return __session!;
  }

  /// Throws an exception if [errorMessage] is non-empty.
  void handleErrorMessage(Pointer<Pointer<Char>> errorMessage, [int? status]) {
    if (errorMessage.isNotNullPointer && errorMessage[0].isNotNullPointer) {
      final dartErrorMessage = errorMessage.toDartStrings(1);
      _log.severe('Inference Error: $dartErrorMessage');

      // If there is an exception, release this memory because the calling code
      // will not get a chance to.
      errorMessage.free(1);

      // Raise the exception.
      if (status == null) {
        throw Exception('Inference Error: $dartErrorMessage');
      } else {
        throw Exception('Inference Error: Status $status :: $dartErrorMessage');
      }
    }
  }

  @override
  Stream<String> generateResponse(String text) {
    assert(() {
      if (_responseController != null) {
        throw Exception(
          'Asked for response before completing response from '
          'previous query, or cancelling previous query.',
        );
      }
      return true;
    }());
    _responseController = StreamController<String>();
    final textPtr = text.copyToNative();
    print('copied $text to native');
    final callback = NativeCallable<LlmResponseCallback>.listener(
      (
        Pointer<Void> context,
        bindings.LlmResponseContext responseContext,
      ) {
        print('in callback');
        if (_responseController == null) {
          // Short-circuit if the caller has cancelled this query before receiving
          // the complete output.
          return;
        }
        final responseChunk = responseContext.response_array
            .toDartStrings(responseContext.response_count);
        print('responseChunk :: $responseChunk');
        _responseController!.add(responseChunk.join(' '));
        if (responseContext.done) {
          _finalizeResponse();
        }
      },
    );
    print('created callback');
    bindings.LlmInferenceEngine_Session_PredictAsync(
      _session.value,
      nullptr,
      textPtr,
      callback.nativeFunction,
    );
    print('called predictAsync');
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
    if (__session != null) {
      bindings.LlmInferenceEngine_Session_Delete(__session!.value);
    }
    if (_responseController != null) {
      _finalizeResponse();
    }
  }

  @override
  int sizeInTokens(String text) {
    // TODO: implement sizeInTokens
    throw UnimplementedError();
  }
}

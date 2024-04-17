// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_genai/interface.dart';
import 'package:mediapipe_genai/io.dart';
import 'package:mediapipe_genai/src/io/third_party/mediapipe/generated/mediapipe_genai_bindings.dart'
    as bindings;

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

  Pointer<Void>? __session;

  Pointer<Void> get _session {
    if (__session == null) {
      __session = bindings.LlmInferenceEngine_CreateSession(
        _options.copyToNative(),
      );
      // Releases the pointer created by `copyToNative`
      _options.dispose();
    }
    return __session!;
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
    final sessionContext = malloc<Void>();
    final callback = NativeCallable<LlmResponseCallback>.listener(
      (
        Pointer<Void> context,
        bindings.LlmResponseContext response,
      ) {
        if (_responseController == null) {
          // Short-circuit if the caller has cancelled this query before receiving
          // the complete output.
          return;
        }
        final responseChunk =
            response.response_array.toDartStrings(response.response_count);
        _responseController!.add(responseChunk.join(' '));
        if (response.done) {
          _finalizeResponse();
        }
      },
    );

    bindings.LlmInferenceEngine_Session_PredictAsync(
      _session,
      sessionContext,
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
    if (__session != null) {
      bindings.LlmInferenceEngine_Session_Delete(__session!);
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

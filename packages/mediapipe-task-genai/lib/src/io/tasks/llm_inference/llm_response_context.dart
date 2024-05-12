// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_genai/interface.dart';
import '../../third_party/mediapipe/generated/mediapipe_genai_bindings.dart'
    as bindings;

final _log = Logger('LlmResponseContext');

/// {@macro LlmResponseContext}
class LlmResponseContext extends BaseLlmResponseContext with IOTaskResult {
  /// {@macro LlmResponseContext.fake}
  LlmResponseContext(
      {required List<String> responseArray, required bool isDone})
      : _responseArray = responseArray,
        _isDone = isDone;

  /// {@template LlmResponseContext.native}
  /// Initializes a [LlmResponseContext] instance as a wrapper around native
  /// memory.
  ///
  /// See also:
  ///  * [LlmInferenceEngine.generateResponse] where this is called.
  /// {@endtemplate}
  LlmResponseContext.native(this._pointer);

  Pointer<bindings.LlmResponseContext>? _pointer;

  List<String>? _responseArray;
  @override
  List<String> get responseArray => _responseArray ??= _getResponseArray();
  List<String> _getResponseArray() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'No native memory for LlmResponseContext.responseArray',
      );
    }
    // Should be able to be removed after b/339661277
    if (_pointer!.ref.response_array == nullptr) {
      _log.warning('LlmResponseContext.response_array unexpectedly nullptr');
      return [''];
    }
    return _pointer!.ref.response_array.toDartStrings(
      _pointer!.ref.response_count,
    );
  }

  bool? _isDone;
  @override
  bool get isDone => _isDone ??= _getIsDone();
  bool _getIsDone() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'No native memory for LlmResponseContext.isDone',
      );
    }
    return _pointer!.ref.done;
  }

  @override
  void dispose() {
    assert(() {
      if (isClosed) {
        throw Exception(
          'A LlmResponseContext was closed after it had already been closed. '
          'LlmResponseContext objects should only be closed when they are at'
          'their end of life and will never be used again.',
        );
      }
      return true;
    }());
    if (_pointer != null) {
      // Only call the native finalizer if there actually is native memory,
      // because tests may verify that faked results are also closed and calling
      // this method in that scenario would cause a segfault.
      bindings.LlmInferenceEngine_CloseResponseContext(_pointer!);
    }
    super.dispose();
  }
}

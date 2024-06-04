// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';

import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/interface.dart';
import '../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@macro TextClassifierResult}
class TextClassifierResult extends BaseTextClassifierResult with IOTaskResult {
  /// {@macro TextClassifierResult.fake}
  TextClassifierResult({required Iterable<Classifications> classifications})
      : _classifications = classifications,
        _pointer = null;

  /// {@template TextClassifierResult.native}
  /// Initializes a [TextClassifierResult] instance as a wrapper around native
  /// memory.
  ///
  /// See also:
  ///  * [TextClassifierExecutor.classify] where this is called.
  /// {@endtemplate}
  TextClassifierResult.native(this._pointer);

  final Pointer<bindings.TextClassifierResult>? _pointer;

  Iterable<Classifications>? _classifications;
  @override
  Iterable<Classifications> get classifications =>
      _classifications ??= _getClassifications();
  Iterable<Classifications> _getClassifications() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'No native memory for TextClassifierResult.classifications',
      );
    }
    return Classifications.fromNativeArray(
      _pointer!.ref.classifications,
      _pointer.ref.classifications_count,
    );
  }

  @override
  void dispose() {
    assert(() {
      if (isClosed) {
        throw Exception(
          'A TextClassifierResult was closed after it had already been closed. '
          'TextClassifierResult objects should only be closed when they are at'
          'their end of life and will never be used again.',
        );
      }
      return true;
    }());
    if (_pointer != null) {
      // Only call the native finalizer if there actually is native memory,
      // because tests may verify that faked results are also closed and calling
      // this method in that scenario would cause a segfault.
      bindings.text_classifier_close_result(_pointer);
    }
    super.dispose();
  }
}

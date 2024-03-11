// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';

import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/interface.dart';
import '../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@macro TextClassifierResult}
class TextClassifierResult extends BaseTextClassifierResult with TaskResult {
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

  bool _isClosed = false;

  /// [True] if [dispose] has been called.
  bool get isClosed => _isClosed;

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
      _pointer!.ref.classifications_count,
    );
  }

  @override
  void dispose() {
    if (_pointer != null && !_isClosed) {
      bindings.text_classifier_close_result(_pointer!);
    }
    _isClosed = true;
  }
}

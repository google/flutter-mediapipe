// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';

import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/interface.dart';
import '../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@macro TextClassifierResult}
class TextClassifierResult extends ITextClassifierResult with TaskResult {
  /// {@macro ClassifierResult.fake}
  TextClassifierResult.fake({required List<Classifications> classifications})
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

  Pointer<bindings.TextClassifierResult>? _pointer;

  List<Classifications>? _classifications;
  @override
  List<Classifications> get classifications =>
      _classifications ??= _getClassifications();
  List<Classifications> _getClassifications() {
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
    if (_pointer != null) {
      bindings.text_classifier_close_result(_pointer!);
      _pointer = null;
    }
  }
}

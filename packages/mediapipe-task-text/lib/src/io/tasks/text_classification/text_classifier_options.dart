// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/interface.dart';
import '../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@macro TextClassifierOptions}
// ignore: must_be_immutable
class TextClassifierOptions extends BaseTextClassifierOptions
    with TaskOptions<bindings.TextClassifierOptions> {
  /// {@macro TextClassifierOptions}
  TextClassifierOptions({
    required this.baseOptions,
    this.classifierOptions = const ClassifierOptions(),
  });

  /// {@macro TextClassifierOptions.fromAssetPath}
  factory TextClassifierOptions.fromAssetPath(
    String assetPath, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  }) {
    return TextClassifierOptions(
      baseOptions: BaseOptions.path(assetPath),
      classifierOptions: classifierOptions,
    );
  }

  /// {@macro TextClassifierOptions.fromAssetBuffer}
  factory TextClassifierOptions.fromAssetBuffer(
    Uint8List assetBuffer, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  }) =>
      TextClassifierOptions(
        baseOptions: BaseOptions.memory(assetBuffer),
        classifierOptions: classifierOptions,
      );

  @override
  final BaseOptions baseOptions;

  @override
  final ClassifierOptions classifierOptions;

  /// Cache of the pointer to the native memory created in [copyToNative].
  /// This pointer is held locally to make `free` an instance method, which is
  /// simpler to call in [TaskExecutor], which only knows about a [TaskOptions]
  /// type and does not know the final type until runtime. This is relevant
  /// because `TaskOptions.free` should be static if it accepted the pointer to
  /// release, but Dart cannot call static methods off a generic type.
  Pointer<bindings.TextClassifierOptions>? _pointer;

  bool _isClosed = false;

  @override
  Pointer<bindings.TextClassifierOptions> copyToNative() {
    _pointer = calloc<bindings.TextClassifierOptions>();
    baseOptions.assignToStruct(_pointer!.ref.base_options);
    classifierOptions.assignToStruct(_pointer!.ref.classifier_options);
    return _pointer!;
  }

  @override
  void dispose() {
    if (_isClosed) return;
    baseOptions.freeStructFields(_pointer!.ref.base_options);
    classifierOptions.freeStructFields(_pointer!.ref.classifier_options);
    calloc.free(_pointer!);
    _isClosed = true;
  }
}

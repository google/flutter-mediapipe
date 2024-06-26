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
///
/// This io-friendly implementation is not immutable strictly for memoization of
/// computed fields. All values used by pkg:equatable are in fact immutable.
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

  /// {@template TaskOptions.memory}
  /// Cache of the pointer to the native memory created in [copyToNative].
  /// This pointer is held locally to make `free` an instance method, which is
  /// simpler to call in [TaskExecutor], which only knows about a [TaskOptions]
  /// type and does not know the final type until runtime. This is relevant
  /// because `TaskOptions.free` should be static if it accepted the pointer to
  /// release, but Dart cannot call static methods off a generic type.
  /// {@endtemplate}
  Pointer<bindings.TextClassifierOptions>? _pointer;

  @override
  Pointer<bindings.TextClassifierOptions> copyToNative() {
    _pointer = calloc<bindings.TextClassifierOptions>();
    baseOptions.assignToStruct(_pointer!.ref.base_options);
    classifierOptions.assignToStruct(_pointer!.ref.classifier_options);
    return _pointer!;
  }

  bool _isClosed = false;

  /// Tracks whether [dispose] has been called.
  bool get isClosed => _isClosed;

  @override
  void dispose() {
    assert(() {
      if (isClosed) {
        throw Exception(
          'Attempted to call dispose on an already-disposed task options'
          'object. Task options should only ever be disposed after they are at '
          'end-of-life and will never be accessed again.',
        );
      }
      if (_pointer == null) {
        throw Exception(
          'Attempted to call dispose on a TextClassifierOptions object which '
          'was never used by a TextClassifier. Did you forget to create your '
          'TextClassifier?',
        );
      }
      return true;
    }());
    baseOptions.freeStructFields(_pointer!.ref.base_options);
    classifierOptions.freeStructFields(_pointer!.ref.classifier_options);
    calloc.free(_pointer!);
    _isClosed = true;
  }
}

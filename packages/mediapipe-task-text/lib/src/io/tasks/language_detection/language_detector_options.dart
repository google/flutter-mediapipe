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

/// {@macro LanguageDetectorOptions}
///
/// This io-friendly implementation is not immutable strictly for memoization of
/// computed fields. All values used by pkg:equatable are in fact immutable.
// ignore: must_be_immutable
class LanguageDetectorOptions extends BaseLanguageDetectorOptions
    with TaskOptions<bindings.LanguageDetectorOptions> {
  /// {@macro LanguageDetectorOptions}
  LanguageDetectorOptions({
    required this.baseOptions,
    this.classifierOptions = const ClassifierOptions(),
  });

  /// {@macro LanguageDetectorOptions.fromAssetPath}
  factory LanguageDetectorOptions.fromAssetPath(
    String assetPath, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  }) {
    return LanguageDetectorOptions(
      baseOptions: BaseOptions.path(assetPath),
      classifierOptions: classifierOptions,
    );
  }

  /// {@macro LanguageDetectorOptions.fromAssetBuffer}
  factory LanguageDetectorOptions.fromAssetBuffer(
    Uint8List assetBuffer, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  }) =>
      LanguageDetectorOptions(
        baseOptions: BaseOptions.memory(assetBuffer),
        classifierOptions: classifierOptions,
      );

  @override
  final BaseOptions baseOptions;

  @override
  final ClassifierOptions classifierOptions;

  /// {@macro TaskOptions.memory}
  Pointer<bindings.LanguageDetectorOptions>? _pointer;

  @override
  Pointer<bindings.LanguageDetectorOptions> copyToNative() {
    _pointer = calloc<bindings.LanguageDetectorOptions>();
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
          'Attempted to call dispose on a LanguageDetectorOptions object which '
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

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/interface.dart';
import '../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@macro TextEmbedderOptions}
///
/// This io-friendly implementation is not immutable strictly for memoization of
/// computed fields. All values used by pkg:equatable are in fact immutable.
// ignore: must_be_immutable
class TextEmbedderOptions extends BaseTextEmbedderOptions
    with TaskOptions<bindings.TextEmbedderOptions> {
  /// {@macro TextEmbedderOptions}
  TextEmbedderOptions({
    required this.baseOptions,
    this.embedderOptions = const EmbedderOptions(),
  });

  /// {@macro TextEmbedderOptions.fromAssetPath}
  factory TextEmbedderOptions.fromAssetPath(
    String assetPath, {
    EmbedderOptions embedderOptions = const EmbedderOptions(),
  }) {
    return TextEmbedderOptions(
      baseOptions: BaseOptions.path(assetPath),
      embedderOptions: embedderOptions,
    );
  }

  /// {@macro TextEmbedderOptions.fromAssetBuffer}
  factory TextEmbedderOptions.fromAssetBuffer(
    Uint8List assetBuffer, {
    EmbedderOptions embedderOptions = const EmbedderOptions(),
  }) =>
      TextEmbedderOptions(
        baseOptions: BaseOptions.memory(assetBuffer),
        embedderOptions: embedderOptions,
      );

  @override
  final BaseOptions baseOptions;

  @override
  final EmbedderOptions embedderOptions;

  /// {@macro TaskOptions.memory}
  Pointer<bindings.TextEmbedderOptions>? _pointer;

  @override
  Pointer<bindings.TextEmbedderOptions> copyToNative() {
    _pointer = calloc<bindings.TextEmbedderOptions>();
    baseOptions.assignToStruct(_pointer!.ref.base_options);
    embedderOptions.assignToStruct(_pointer!.ref.embedder_options);
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
          'A TextEmbedderResult was closed after it had already been closed. '
          'TextEmbedderResult objects should only be closed when they are at'
          'their end of life and will never be used again.',
        );
      }
      if (_pointer == null) {
        throw Exception(
          'Attempted to call dispose on a TextEmbedderOptions object which '
          'was never used by a TextEmbedder. Did you forget to create your '
          'TextEmbedder?',
        );
      }
      return true;
    }());
    baseOptions.freeStructFields(_pointer!.ref.base_options);
    embedderOptions.freeStructFields(_pointer!.ref.embedder_options);
    calloc.free(_pointer!);
    _isClosed = true;
  }
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:math';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/interface.dart';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_genai/interface.dart';

import '../../third_party/mediapipe/generated/mediapipe_genai_bindings.dart'
    as bindings;

/// {@macro LlmInferenceOptions}
///
/// This io-friendly implementation is not immutable to track whether the
/// native memory has been created and ultimately released. All values used by
/// pkg:equatable are in fact immutable.
// ignore: must_be_immutable
class LlmInferenceOptions extends BaseLlmInferenceOptions {
  /// {@macro LlmInferenceOptions}
  LlmInferenceOptions({
    required this.modelPath,
    required this.maxTokens,
    required this.temperature,
    required this.topK,
    int? randomSeed,
  }) : randomSeed = randomSeed ?? Random().nextInt(1 << 32);

  Pointer<bindings.LlmSessionConfig>? _pointer;

  @override
  final String modelPath;

  @override
  final int maxTokens;

  @override
  final int randomSeed;

  @override
  final double temperature;

  @override
  final int topK;

  /// Copies this options object into native memory for use by an engine.
  Pointer<bindings.LlmSessionConfig> copyToNative() {
    _pointer = malloc<bindings.LlmSessionConfig>();
    _pointer!.ref.model_path = modelPath.copyToNative();
    _pointer!.ref.max_tokens = maxTokens;
    _pointer!.ref.random_seed = randomSeed;
    _pointer!.ref.temperature = temperature;
    _pointer!.ref.topk = topK;
    return _pointer!;
  }

  bool _isClosed = false;

  /// Tracks whether [dispose] has been called.
  bool get isClosed => _isClosed;

  /// Releases the native memory behind this options object.
  void dispose() {
    assert(() {
      if (isClosed) {
        throw Exception(
          'Attempted to call dispose on an already-disposed LlmInferenceOptions '
          'object. LlmInferenceOptions should only ever be disposed after they '
          'are at end-of-life and will never be accessed again.',
        );
      }
      if (_pointer == null) {
        throw Exception(
          'Attempted to call dispose on a LlmInferenceOptions object which '
          'was never used by an LLM. Did you forget to create your LLM?',
        );
      }
      return true;
    }());
    calloc.free(_pointer!.ref.model_path);
    calloc.free(_pointer!);
    _isClosed = true;
  }
}

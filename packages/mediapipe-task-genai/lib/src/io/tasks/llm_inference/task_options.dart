// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:math';
import 'package:ffi/ffi.dart';
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
  /// {@macro LlmInferenceOptions.cpu}
  LlmInferenceOptions.cpu({
    required this.modelPath,
    // `cacheDir` is optional on the class as a whole, but is required for the
    // CPU scenario - thus we do not use `this.cacheDir` so as to upgrade the
    // parameter requirements and remove nullability
    required String cacheDir,
    required this.maxTokens,
    required this.temperature,
    required this.topK,
    int? randomSeed,
    // ignore: prefer_initializing_formals
  })  : cacheDir = cacheDir,
        sequenceBatchSize = 0,
        decodeStepsPerSync = 0,
        randomSeed = randomSeed ?? Random().nextInt(1 << 32);

  /// {@macro LlmInferenceOptions.gpu}
  LlmInferenceOptions.gpu({
    required this.modelPath,
    required this.sequenceBatchSize,
    required this.maxTokens,
    required this.temperature,
    required this.topK,
    this.decodeStepsPerSync = 3,
    int? randomSeed,
  })  : cacheDir = null,
        randomSeed = randomSeed ?? Random().nextInt(1 << 32);

  Pointer<bindings.LlmSessionConfig>? _pointer;

  @override
  final String modelPath;

  @override
  final String? cacheDir;

  @override
  final int sequenceBatchSize;

  @override
  final int decodeStepsPerSync;

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
    _pointer!.ref.cache_dir = cacheDir?.copyToNative() ?? nullptr;
    _pointer!.ref.sequence_batch_size = sequenceBatchSize;
    _pointer!.ref.num_decode_steps_per_sync = decodeStepsPerSync;
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

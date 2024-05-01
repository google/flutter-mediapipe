// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_genai/interface.dart';

/// {@macro LlmInferenceEngine}
class LlmInferenceEngine extends BaseLlmInferenceEngine {
  /// {@macro LlmInferenceEngine}
  LlmInferenceEngine(LlmInferenceOptions options);

  @override
  Stream<String> generateResponse(String text) => throw UnimplementedError();

  @override
  int sizeInTokens(String text) => throw UnimplementedError();
}

/// {@macro LlmInferenceOptions}
class LlmInferenceOptions extends BaseLlmInferenceOptions {
  /// {@template LLmInferenceOptions.cpu}
  /// {@macro LlmInferenceOptions}
  ///
  /// Constructor for inference models using the CPU.
  /// {@endtemplate}
  factory LlmInferenceOptions.cpu({
    required String modelPath,
    required String cacheDir,
    required int maxTokens,
    required double temperature,
    required int topK,
    int? randomSeed,
  }) =>
      throw UnimplementedError();

  /// {@template LLmInferenceOptions.gpu}
  /// {@macro LlmInferenceOptions}
  ///
  /// Constructor for inference models using the GPU.
  /// {@endtemplate}
  factory LlmInferenceOptions.gpu({
    required String modelPath,
    required int sequenceBatchSize,
    required int maxTokens,
    required double temperature,
    required int topK,
    int decodeStepsPerSync = 3,
    int? randomSeed,
  }) =>
      throw UnimplementedError();

  @override
  String get modelPath => throw UnimplementedError();

  @override
  String? get cacheDir => throw UnimplementedError();

  @override
  int get sequenceBatchSize => throw UnimplementedError();

  @override
  int get decodeStepsPerSync => throw UnimplementedError();

  @override
  int get maxTokens => throw UnimplementedError();

  @override
  int get randomSeed => throw UnimplementedError();

  @override
  double get temperature => throw UnimplementedError();

  @override
  int get topK => throw UnimplementedError();
}

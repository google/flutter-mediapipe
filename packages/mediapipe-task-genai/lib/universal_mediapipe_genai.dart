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
  /// {@macro LlmInferenceOptions}
  LlmInferenceOptions({
    required String modelPath,
    required int maxTokens,
    required double temperature,
    required int topK,
    int? randomSeed,
  });

  @override
  String get modelPath => throw UnimplementedError();

  @override
  int get maxTokens => throw UnimplementedError();

  @override
  int get randomSeed => throw UnimplementedError();

  @override
  double get temperature => throw UnimplementedError();

  @override
  int get topK => throw UnimplementedError();
}

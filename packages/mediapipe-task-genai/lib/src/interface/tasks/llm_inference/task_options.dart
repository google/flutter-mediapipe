// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:equatable/equatable.dart';

/// {@template LlmInferenceOptions}
/// Configuration object for a MediaPipe text classifier.
///
/// See also:
///  * [MediaPipe's LlmInferenceOptions documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/genai/llminference/LlmInference.LlmInferenceOptions)
/// {@endtemplate}
abstract class BaseLlmInferenceOptions extends Equatable {
  /// The total length of the kv-cache.
  int get maxTokens;

  /// Random seed for sampling tokens.
  int get randomSeed;

  /// Randomness when decoding the next token.
  double get temperature;

  /// Top K number of tokens to be sampled from for each decoding step.
  int get topK;

  @override
  List<Object?> get props => [maxTokens, randomSeed, temperature, topK];
}

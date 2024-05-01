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
  /// The path that points to the tflite model file to use for inference.
  String get modelPath;

  /// Directory path for storing model related tokenizer and cache weights. The
  /// user is responsible for providing the directory that can be writable by the
  /// program. Used by CPU only.
  String? get cacheDir;

  /// Sequence batch size for encoding. Used by GPU only. Number of input tokens
  /// to process at a time for batch processing. Setting this value to 1 means
  /// both the encoding and decoding share the same graph of sequence length
  /// of 1. Setting this value to 0 means the batch size will be optimized
  /// programmatically.
  int get sequenceBatchSize;

  /// Number of decode steps per sync. Used by GPU only. The default value is 3.
  int get decodeStepsPerSync;

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

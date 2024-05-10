// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// {@template LlmInferenceEngine}
/// Utility to query an LLM with a prompt and receive its response as a stream.
/// {@endtemplate}
abstract class BaseLlmInferenceEngine {
  /// {@template generateResponse}
  /// Generates a response based on the input text.
  /// {@endtemplate}
  Stream<String> generateResponse(String text);

  /// {@template sizeInTokens}
  /// Runs an invocation of only the tokenization for the LLM, and returns the
  /// size (in tokens) of the result.
  /// {@endtemplate}
  Future<int> sizeInTokens(String text);
}

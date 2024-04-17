// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// {@template LlmInferenceEngine}
/// Utility to query an LLM with a prompt and receive its response as a stream.
/// {@endtemplate}
abstract class BaseLlmInferenceEngine {
  /// Generates a response based on the input text.
  Stream<String> generateResponse(String text);

  /// Runs an invocation of only the tokenization for the LLM, and returns the
  /// size (in tokens) of the result.
  int sizeInTokens(String text);
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/interface.dart';

/// {@template LlmResponseContext}
/// Represents all of or part of an LLM's response to a query.
/// {@endtemplate}
abstract class BaseLlmResponseContext extends TaskResult {
  /// The core of the LLM's response from this query. If the asynchronous
  /// API is used, this [response] value should be chained with subsequent
  /// values until the LLM emits one with [isDone] set to true.
  List<String> get responseArray;

  /// Indicates when an LLM is done responding. Only useful when calling the
  /// asynchronous methods.
  bool get isDone;

  @override
  String toString() {
    return '$runtimeType(responseArray=$responseArray, isDone: $isDone)';
  }
}

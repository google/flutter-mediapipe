// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/mediapipe_core.dart';
import 'text_embedding.dart';

/// {@template TextEmbedder}
/// Utility to convert text into an embedding suitable for other MediaPipe tasks.
/// {@endtemplate}
abstract class BaseTextEmbedder {
  /// {@template TextEmbedder.embed}
  /// Sends a [String] value to MediaPipe for conversion into an [Embedding].
  /// {@endtemplate}
  Future<BaseTextEmbedderResult> embed(String text);

  /// {@template TextEmbedder.cosineSimilarity}
  /// Sends a [String] value to MediaPipe for conversion into an [Embedding].
  /// {@endtemplate}
  Future<double> cosineSimilarity(Embedding a, Embedding b);

  /// Cleans up all resources.
  void dispose();
}

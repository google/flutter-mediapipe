// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';

export 'universal_text_embedder.dart'
    if (dart.library.html) 'text_embedder_web.dart'
    if (dart.library.io) 'text_embedder_io.dart';

/// {@template TextEmbedder}
/// Performs embedding extraction on text.
///
/// See also:
///   * [MediaPipe documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/textembedder/TextEmbedder)
/// {@endtemplate}
abstract class BaseTextEmbedder {
  /// {@macro TextEmbedder}
  BaseTextEmbedder({required this.options});

  /// Configuration object for tasks completed by this embedder.
  final TextEmbedderOptions options;

  /// {@template textEmbed}
  /// Performs embedding extraction on the input text.
  /// {@endtemplate}
  Future<TextEmbedderResult> embed(String text);

  /// {@template cosineSimilarity}
  /// Utility function to compute cosine similarity between two [Embedding]
  /// objects.
  ///
  /// See also:
  ///   * [Cosine similarity](https://en.wikipedia.org/wiki/Cosine_similarity)
  /// {@endtemplate}
  // TODO: Could this function be static?
  Future<double> cosineSimilarity(Embedding a, Embedding b);

  /// {@template textEmbedderDipose}
  /// Closes down this TextEmbedder and releases all resources.
  /// {@endtemplate}
  void dispose();
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';

/// {@macro TextEmbedder}
class TextEmbedder extends BaseTextEmbedder {
  /// {@macro TextEmbedder}
  TextEmbedder({required super.options}) {
    throw Exception('Must use the web or FFI implementations');
  }

  /// {@macro textEmbed}
  @override
  Future<TextEmbedderResult> embed(String text) {
    throw Exception('Must use the web or FFI implementations');
  }

  /// {@macro cosineSimilarity}
  @override
  Future<double> cosineSimilarity(Embedding a, Embedding b) {
    throw Exception('Must use the web or FFI implementations');
  }

  /// {@macro textEmbedderDipose}
  @override
  void dispose() {
    throw Exception('Must use the web or FFI implementations');
  }
}

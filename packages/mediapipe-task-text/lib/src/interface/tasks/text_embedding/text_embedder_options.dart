// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/interface.dart';

/// {@template TextEmbedderOptions}
/// Configuration object for a MediaPipe text embedder.
///
/// See also:
///  * [MediaPipe's TextEmbedderOptions documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/textembedder/TextEmbedder.TextEmbedderOptions)
/// {@endtemplate}
abstract class BaseTextEmbedderOptions extends BaseTaskOptions {
  /// Contains parameter options for how this embedder should behave.
  BaseEmbedderOptions get embedderOptions;

  @override
  String toString() => 'TextEmbedderOptions(baseOptions: $baseOptions, '
      'embedderOptions: $embedderOptions)';

  @override
  List<Object?> get props => [baseOptions, embedderOptions];
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/src/third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// Container with results of MediaPipe's `classifyText` task.
///
/// See also:
///  * [MediaPipe's textClassifierResult documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/textclassifier/TextClassifierResult)
class TextClassifierResult {
  /// Generative constructor which creates a [TextClassifierResult] instance.
  const TextClassifierResult({
    required this.classifications,
    this.timestamp,
  });

  /// The classification results for each head of the model.
  final List<Classifications> classifications;

  /// The optional timestamp (as a [Duration]) of the start of the chunk of data
  /// corresponding to these results.
  ///
  /// This is only used for classification on time series (e.g. audio
  /// classification). In these use cases, the amount of data to process might
  /// exceed the maximum size that the model can process: to solve this, the
  /// input data is split into multiple chunks starting at different timestamps.
  final Duration? timestamp;

  /// Factory constructor which converts the C representation of an
  /// ImageClassifierResult into an actual [ImageClassifierResult].
  factory TextClassifierResult.fromStruct(
      bindings.TextClassifierResult struct) {
    return TextClassifierResult(
      classifications: Classifications.fromStructs(
        struct.classifications,
        struct.classifications_count,
      ),
      timestamp: struct.has_timestamp_ms
          ? Duration(milliseconds: struct.timestamp_ms)
          : null,
    );
  }

  /// Convenience helper for the first [Classifications] object.
  Classifications? get firstClassification =>
      classifications.isNotEmpty ? classifications.first : null;

  @override
  String toString() {
    final classificationStrings =
        classifications.map((cat) => cat.toString()).join(', ');
    return 'TextClassifierResult(classifications=[$classificationStrings], '
        'timestamp=$timestamp)';
  }
}

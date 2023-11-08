import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../../../../third_party/mediapipe/mediapipe_vision_bindings.dart'
    as bindings;

/// Container with results of MediaPipe's `classifyImage` task.
///
/// See also:
///  * [MediaPipe's ImageClassifierResult documentation](https://developers.google.com/mediapipe/api/solutions/js/tasks-vision.imageclassifierresult)
class ImageClassifierResult {
  /// Generative constructor which creates an [ImageClassifierResult] instance.
  const ImageClassifierResult({
    required this.classifications,
    this.timestamp,
  });

  /// The classification results for each head of the model.
  final List<Classifications> classifications;

  /// The optional timestamp (as a Duration) of the start of the chunk of data
  /// corresponding to these results.
  ///
  /// This is only used for classification on time series (e.g. audio
  /// classification). In these use cases, the amount of data to process might
  /// exceed the maximum size that the model can process: to solve this, the
  /// input data is split into multiple chunks starting at different timestamps.
  final Duration? timestamp;

  /// Factory constructor which converts the C representation of an
  /// ImageClassifierResult into an actual [ImageClassifierResult].
  factory ImageClassifierResult.fromStruct(
    bindings.ImageClassifierResult struct,
  ) =>
      ImageClassifierResult(
        classifications: Classifications.fromStructs(
          struct.classifications,
          struct.classifications_count,
        ),
        timestamp: struct.has_timestamp_ms
            ? Duration(milliseconds: struct.timestamp_ms)
            : null,
      );

  /// Deallocates all memory associated with an [bindings.ImageClassifierResult]
  /// in C memory.
  static void freeStruct(Pointer<bindings.ImageClassifierResult> struct) {
    Classifications.freeStructs(
      struct.ref.classifications,
      struct.ref.classifications_count,
    );
    calloc.free(struct);
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

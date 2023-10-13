import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/src/mediapipe_text_bindings.dart' as bindings;

class TextClassifierResult {
  const TextClassifierResult({
    required this.classifications,
    this.timestamp,
  });

  // The classification results for each head of the model.
  final List<Classifications> classifications;

  // The optional timestamp (as a Duration) of the start of the chunk of data
  // corresponding to these results.
  //
  // This is only used for classification on time series (e.g. audio
  // classification). In these use cases, the amount of data to process might
  // exceed the maximum size that the model can process: to solve this, the
  // input data is split into multiple chunks starting at different timestamps.
  final Duration? timestamp;

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

  static void freeStruct(Pointer<bindings.TextClassifierResult> struct) {
    Classifications.freeStructs(
      struct.ref.classifications,
      struct.ref.classifications_count,
    );
    calloc.free(struct);
  }

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

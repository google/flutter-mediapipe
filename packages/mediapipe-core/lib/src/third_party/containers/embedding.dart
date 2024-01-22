import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../mediapipe/generated/mediapipe_common_bindings.dart' as bindings;

/// Marker for which flavor of analysis was performed for a specific
/// [Embedding] instance.
enum EmbeddingType {
  /// Indicates an [Embedding] object has a non-null value for
  /// [Embedding.floatEmbedding].
  float,

  /// Indicates an [Embedding] object has a non-null value for
  /// [Embedding.quantizedEmbedding].
  quantized
}

/// {@template Embedding}
/// Represents the embedding for a given embedder head. Typically used in
/// mbedding tasks.
///
/// One and only one of the two 'floatEmbedding' and 'quantizedEmbedding' will
/// contain data, based on whether or not the embedder was configured to perform
/// scala quantization.
/// {@endtemplate}
class Embedding {
  /// {@macro EmbeddingResult}
  const Embedding._({
    this.floatEmbedding,
    this.quantizedEmbedding,
    required this.headIndex,
    required this.headName,
    required this.type,
  }) : assert(
          (floatEmbedding == null) != (quantizedEmbedding == null),
          'Must supply exactly one of `floatEmbedding` and '
          '`quantizedEmbedding`.',
        );

  /// Instantiates an [Embedding] object for an embedder configured to perform
  /// float embedding.
  factory Embedding.float(
    List<double> floatEmbedding, {
    required int headIndex,
    required String? headName,
  }) =>
      Embedding._(
        floatEmbedding: floatEmbedding,
        headIndex: headIndex,
        headName: headName,
        type: EmbeddingType.float,
      );

  /// Instantiates an [Embedding] object for an embedder configured to perform
  /// quantized embedding.
  factory Embedding.quantized(
    Uint8List quantizedEmbedding, {
    required int headIndex,
    required String? headName,
  }) =>
      Embedding._(
        quantizedEmbedding: quantizedEmbedding,
        headIndex: headIndex,
        headName: headName,
        type: EmbeddingType.quantized,
      );

  /// Accepts a pointer to a list of structs, and a count representing the
  /// length of the list, and returns a list of pure-Dart [Embedding] instances.
  static List<Embedding> structsToDart(
    Pointer<bindings.Embedding> structs,
    int count,
  ) {
    final embeddings = <Embedding>[];
    for (int i = 0; i < count; i++) {
      embeddings.add(structToDart(structs[i]));
    }
    return embeddings;
  }

  /// Accepts a pointer to a single struct and returns a pure-Dart [Embedding]
  /// instance.
  static Embedding structToDart(bindings.Embedding struct) {
    if (struct.float_embedding.isNotNullPointer) {
      return Embedding.float(
        toDartListDouble(struct.float_embedding),
        headIndex: struct.head_index,
        headName: toDartString(struct.head_name),
      );
    } else if (struct.quantized_embedding.isNotNullPointer) {
      return Embedding.quantized(
        toUint8List(struct.quantized_embedding),
        headIndex: struct.head_index,
        headName: toDartString(struct.head_name),
      );
    }
    throw Exception(
      'Unexpectedly encountered Embedding struct with nullptr for BOTH '
      'quantized_embedding AND float_embedding',
    );
  }

  /// Releases all C memory associated with a list of [bindings.Embedding] pointers.
  /// This method is important to call after calling [Embedding.structsToDart].
  static void freeStructs(Pointer<bindings.Embedding> structs, int count) {
    int index = 0;
    while (index < count) {
      bindings.Embedding obj = structs[index];
      Embedding.freeStruct(obj);
      index++;
    }
    calloc.free(structs);
  }

  /// Releases all fields associated with a single [bindings.Embedding] struct.
  static void freeStruct(bindings.Embedding struct) {
    calloc.free(struct.head_name);
    if (struct.quantized_embedding.isNotNullPointer) {
      calloc.free(struct.quantized_embedding);
    }
    if (struct.float_embedding.isNotNullPointer) {
      calloc.free(struct.float_embedding);
    }
  }

  /// Floating-point embedding. [null] if the embedder was configured to perform
  /// scalar-quantization.
  final List<double>? floatEmbedding;

  /// Scalar-quantized embedding. [null] if the embedder was not configured to
  /// perform scalar quantization.
  final Uint8List? quantizedEmbedding;

  /// The index of the embedder head these entries refer to.
  final int headIndex;

  /// The optional name of the embedder head, which is the corresponding
  /// tensor metadata name.
  final String? headName;

  /// Indicator for whether this instance has a non-null value for
  /// [floatEmbedding] or [quantizedEmbedding].
  final EmbeddingType type;
}

/// {@template EmbeddingResult}
/// Represents the embedding results of a model. Typically used as a result for
/// embedding tasks.
///
/// This flavor of embedding result will never have a timestamp.
///
/// See also:
/// * [TimestampedEmbeddingResult] for data which may have a timestamp.
///
/// {@endtemplate}
abstract class EmbeddingResult {
  /// {@macro EmbeddingResult}
  const EmbeddingResult({
    required this.embeddings,
  });

  /// The embedding results for each head of the model.
  final List<Embedding> embeddings;

  @override
  String toString() {
    return '$runtimeType(embeddings=[...${embeddings.length} items])';
  }
}

/// {@template TimestampedEmbeddingResult}
/// Represents the embedding results of a model. Typically used as a result for
/// embedding tasks.
///
/// This flavor of embedding result may have a timestamp.
///
/// See also:
/// * [EmbeddingResult] for data which will not have a timestamp.
///
/// {@endtemplate}
abstract class TimestampedEmbeddingResult extends EmbeddingResult {
  /// {@macro TimstampedEmbeddingResult}
  const TimestampedEmbeddingResult({
    required super.embeddings,
    this.timestamp,
  });

  /// The optional timestamp (as a [Duration]) of the start of the chunk of data
  /// corresponding to these results.
  ///
  /// This is only used for embedding on time series (e.g. audio
  /// embedding). In these use cases, the amount of data to process might
  /// exceed the maximum size that the model can process: to solve this, the
  /// input data is split into multiple chunks starting at different timestamps.
  final Duration? timestamp;

  @override
  String toString() {
    return '$runtimeType(embeddings=[...${embeddings.length} items], '
        'timestamp=$timestamp)';
  }
}

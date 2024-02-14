// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';

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
  quantized;

  /// Returns the opposite type.
  EmbeddingType get opposite => switch (this) {
        EmbeddingType.float => EmbeddingType.quantized,
        EmbeddingType.quantized => EmbeddingType.float,
      };
}

/// {@template Embedding}
/// Represents the embedding for a given embedder head. Typically used in
/// embedding tasks.
///
/// One and only one of 'floatEmbedding' and 'quantizedEmbedding' will contain
/// data, based on whether or not the embedder was configured to perform scala
/// quantization.
/// {@endtemplate}
class Embedding {
  /// {@macro EmbeddingResult}
  // const Embedding._({
  //   this.floatEmbedding,
  //   this.quantizedEmbedding,
  //   required this.length,
  //   required this.headIndex,
  //   required this.headName,
  //   required this.type,
  //   required this.struct,
  // }) : assert(
  //         (floatEmbedding == null) != (quantizedEmbedding == null),
  //         'Must supply exactly one of `floatEmbedding` and '
  //         '`quantizedEmbedding`.',
  //       );

  const Embedding(this.ptr);

  // /// Instantiates an [Embedding] object for an embedder configured to perform
  // /// float embedding.
  // factory Embedding.float(
  //   Pointer<Float> floatEmbedding,
  //   int length, {
  //   required int headIndex,
  //   required String? headName,
  // }) =>
  //     Embedding._(
  //       // floatEmbedding: toFloat32List(floatEmbedding, length: length),
  //       // floatEmbedding: floatEmbedding,

  //       length: length,
  //       headIndex: headIndex,
  //       headName: headName,
  //       type: EmbeddingType.float,
  //     );

  // /// Instantiates an [Embedding] object for an embedder configured to perform
  // /// quantized embedding.
  // factory Embedding.quantized(
  //   Pointer<Char> quantizedEmbedding,
  //   int length, {
  //   required int headIndex,
  //   required String? headName,
  // }) =>
  //     Embedding._(
  //       // quantizedEmbedding: quantizedEmbedding,
  //       // quantizedEmbedding: NativeMemoryManager<Char, Uint8List>.native(
  //       //   quantizedEmbedding,
  //       //   toDart: (ptr) => ptr.toUint8List(length),
  //       // ),
  //       quantizedEmbedding: TypedNativeMemoryManager.nativeUint8List(
  //         quantizedEmbedding,
  //         length,
  //       ),
  //       // quantizedEmbedding: toUint8List(quantizedEmbedding, length: length),
  //       // quantizedEmbedding: Uint8ListMemoryManager(
  //       //   quantizedEmbedding,
  //       //   length: length,
  //       //   finalizer: (Pointer<Char> ptr) => calloc.free(ptr),
  //       // ),
  //       length: length,
  //       headIndex: headIndex,
  //       headName: headName,
  //       type: EmbeddingType.quantized,
  //     );

  /// Accepts a pointer to a list of structs, and a count representing the
  /// length of the list, and returns a list of pure-Dart [Embedding] instances.
  static List<Embedding> fromStructs(
    Pointer<bindings.Embedding> structs,
    int count,
  ) {
    final embeddings = <Embedding>[];
    for (int i = 0; i < count; i++) {
      embeddings.add(Embedding(structs + i));
    }
    return embeddings;
  }

  // Accepts a pointer to a single struct and returns a pure-Dart [Embedding]
  // instance.
  // factory Embedding.fromStruct(bindings.Embedding struct) {
  // if (struct.float_embedding.isNotNullPointer) {
  //   return Embedding.float(
  //     struct.float_embedding,
  //     struct.values_count,
  //     headIndex: struct.head_index,
  //     headName: toDartString(struct.head_name),
  //     struct: struct,
  //   );
  //
  // } else if (struct.quantized_embedding.isNotNullPointer) {
  //   return Embedding.quantized(
  //     struct.quantized_embedding,
  //     struct.values_count,
  //     headIndex: struct.head_index,
  //     headName: toDartString(struct.head_name),
  //   );
  // }
  // throw Exception(
  //     'Unexpectedly encountered Embedding struct with nullptr for BOTH '
  //     'quantized_embedding AND float_embedding',
  //   );
  // }

  // Releases all C memory associated with a list of [bindings.Embedding] pointers.
  // This method is important to call after calling [Embedding.structsToDart].
  // static void freeStructs(Pointer<bindings.Embedding> structs, int count) {
  //   int index = 0;
  //   while (index < count) {
  //     bindings.Embedding obj = structs[index];
  //     Embedding.freeStruct(obj);
  //     index++;
  //   }
  //   calloc.free(structs);
  // }

  // /// Releases all fields associated with a single [bindings.Embedding] struct.
  // static void freeStruct(bindings.Embedding struct) {
  //   calloc.free(struct.head_name);
  //   if (struct.quantized_embedding.isNotNullPointer) {
  //     calloc.free(struct.quantized_embedding);
  //   }
  //   if (struct.float_embedding.isNotNullPointer) {
  //     calloc.free(struct.float_embedding);
  //   }
  // }

  // /// Converts this [Embedding] object into its C representation.
  // bindings.Embedding toStruct() {
  //     final ptr = calloc<bindings.Embedding>();
  //     switch (type) {
  //       case EmbeddingType.float:
  //         print('creating float embedding');
  //         // ptr.ref.float_embedding = floatEmbedding!.toFloatsPointer();
  //         // ptr.ref.float_embedding = floatEmbedding!;
  //         ptr.ref.float_embedding = floatEmbedding!.pointer;
  //         ptr.ref.quantized_embedding = nullptr;
  //       case EmbeddingType.quantized:
  //         print('creating quantized embedding');
  //         // ptr.ref.quantized_embedding = quantizedEmbedding!;
  //         // ptr.ref.quantized_embedding = quantizedEmbedding!.toCharsPointer();
  //         ptr.ref.quantized_embedding = quantizedEmbedding!.pointer;
  //         ptr.ref.float_embedding = nullptr;
  //     }
  //     ptr.ref.values_count = length;
  //     ptr.ref.head_index = headIndex;
  //     if (headName != null) {
  //       ptr.ref.head_name = prepareString(headName!);
  //     }
  //     _struct = ptr.ref;
  //   }
  // }

  /// Floating-point embedding. [null] if the embedder was configured to perform
  /// scalar-quantization.
  Float32List? get floatEmbedding {
    if (type != EmbeddingType.float) {
      return null;
    }
    return _struct.float_embedding.toFloat32List(_struct.values_count);
  }

  /// Scalar-quantized embedding. [null] if the embedder was not configured to
  /// /// perform scalar quantization.
  Uint8List? get quantizedEmbedding {
    if (type != EmbeddingType.quantized) {
      return null;
    }
    return _struct.quantized_embedding.toUint8List(_struct.values_count);
  }

  /// Floating-point embedding. [null] if the embedder was configured to perform
  /// scalar-quantization.
  // final NativeMemoryManager<Float, Float32List>? floatEmbedding;
  // final Pointer<Float>? floatEmbedding;

  // final Float32List? floatEmbedding;
  // final NativeFloat32ListManager? floatEmbedding;

  /// Length of whichever between [floatEmbedding] and [quantizedEmbedding] is
  /// not null.
  // final int length;
  int get length => _struct.values_count;

  /// Scalar-quantized embedding. [null] if the embedder was not configured to
  /// perform scalar quantization.
  // final Pointer<Char>? quantizedEmbedding;
  // final NativeMemoryManager<Char, Uint8List>? quantizedEmbedding;
  // final Uint8ListMemoryManager? quantizedEmbedding;
  // final Uint8List? quantizedEmbedding;

  /// The index of the embedder head these entries refer to.
  // final int headIndex;
  int get headIndex => _struct.head_index;

  /// The optional name of the embedder head, which is the corresponding
  /// tensor metadata name.
  // final String? headName;
  String? get headName => _struct.head_name.toDartString();

  /// Indicator for whether this instance has a non-null value for
  /// [floatEmbedding] or [quantizedEmbedding].
  // final EmbeddingType type;
  EmbeddingType get type => _struct.float_embedding.isNotNullPointer
      ? EmbeddingType.float
      : EmbeddingType.quantized;

  /// The original C struct that hydrated this object.
  final Pointer<bindings.Embedding> ptr;
  bindings.Embedding get _struct => ptr.ref;
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
abstract class EmbeddingResult extends TaskResult {
  /// {@macro EmbeddingResult}
  EmbeddingResult();

  /// The embedding results for each head of the model.
  List<Embedding> get embeddings;

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
  TimestampedEmbeddingResult({this.timestamp});

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

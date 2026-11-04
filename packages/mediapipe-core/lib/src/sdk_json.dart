/// The result containers every family shares, read from the JSON shape of
/// Google's JavaScript API, in which the browser workers deliver them.
library;

import 'dart:typed_data';

import 'value_types.dart';

/// Google's browser runtime reports an absent label as an empty string; its
/// C and Python APIs report none, as the Dart API does.
String? decodeLabel(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Decodes a category. A missing index is -1, as Google's C API reports it.
MediaPipeCategory decodeCategory(Map<Object?, Object?> json) =>
    MediaPipeCategory(
      index: (json['index'] as num?)?.toInt() ?? -1,
      score: (json['score'] as num).toDouble(),
      categoryName: decodeLabel(json['categoryName']),
      displayName: decodeLabel(json['displayName']),
    );

/// Decodes one classification head and its categories.
Classifications decodeClassifications(Map<Object?, Object?> json) =>
    Classifications(
      categories: [
        for (final category in (json['categories'] as List).cast<Map>())
          decodeCategory(category),
      ],
      headIndex: (json['headIndex'] as num?)?.toInt() ?? 0,
      headName: decodeLabel(json['headName']),
    );

/// Decodes one embedding head: its float values or its scalar-quantized
/// bytes, as typed arrays or JSON lists.
Embedding decodeEmbedding(Map<Object?, Object?> json) => Embedding(
  floatEmbedding: switch (json['floatEmbedding']) {
    final Float32List values => values,
    final List values => Float32List.fromList([
      for (final value in values) (value as num).toDouble(),
    ]),
    _ => null,
  },
  quantizedEmbedding: switch (json['quantizedEmbedding']) {
    final Uint8List values => values,
    final List values => Uint8List.fromList([
      for (final value in values) (value as num).toInt(),
    ]),
    _ => null,
  },
  headIndex: (json['headIndex'] as num?)?.toInt() ?? 0,
  headName: decodeLabel(json['headName']),
);

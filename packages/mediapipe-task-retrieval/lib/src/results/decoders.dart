/// Results from the JSON-like maps both runtimes answer in: Google's
/// JavaScript result objects in browsers, and the same shapes, with typed
/// data, from the native worker.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart' show decodeEmbedding;

import '../types/results.dart';

/// A [UniversalEmbedderResult] from `{embeddings: [{floatEmbedding,
/// quantizedEmbedding, headIndex, headName}]}`.
UniversalEmbedderResult decodeEmbedderResult(Object? json) {
  final map = json! as Map;
  return UniversalEmbedderResult(
    embeddings: [
      for (final raw in map['embeddings']! as List) _embedding(raw as Map),
    ],
  );
}

/// One head as core decodes it, except that Google's browser API leaves the
/// unused representation empty, and a head must keep exactly one.
Embedding _embedding(Map map) {
  bool present(Object? value) =>
      value is List ? value.isNotEmpty : value != null;
  final floats = present(map['floatEmbedding']);
  if (floats == present(map['quantizedEmbedding'])) {
    throw const TaskException('MediaPipe returned an invalid embedding.');
  }
  return decodeEmbedding({
    ...map,
    (floats ? 'quantizedEmbedding' : 'floatEmbedding'): null,
  });
}

/// A [RetrievalResult] from `{records: [{id, text, score, metadata}]}`.
RetrievalResult decodeRetrievalResult(Object? json) {
  final map = json! as Map;
  return RetrievalResult(
    records: [
      for (final raw in map['records']! as List)
        RetrievalRecord(
          id: (raw as Map)['id']! as String,
          text: raw['text'] as String? ?? '',
          score: (raw['score']! as num).toDouble(),
          metadata: ((raw['metadata'] as Map?) ?? const {}).map(
            (key, value) => MapEntry(key as String, '$value'),
          ),
        ),
    ],
  );
}

/// The ids from `{ids: [...]}`.
List<String> decodeRecordIds(Object? json) =>
    ((json! as Map)['ids']! as List).cast<String>();

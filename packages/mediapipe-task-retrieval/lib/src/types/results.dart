/// What the retrieval tasks return, identical on every platform.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:meta/meta.dart';

/// Universal Embedder's result: one [Embedding] per output head of the model.
@immutable
final class UniversalEmbedderResult {
  /// Owns an unmodifiable copy of [embeddings].
  UniversalEmbedderResult({required List<Embedding> embeddings})
    : embeddings = List.unmodifiable(embeddings);

  /// The embeddings, in the model's head order; usually one.
  final List<Embedding> embeddings;

  @override
  String toString() => 'UniversalEmbedderResult(embeddings: $embeddings)';
}

/// One record Semantic Retriever found for a query.
@immutable
final class RetrievalRecord {
  /// Owns an unmodifiable copy of [metadata].
  RetrievalRecord({
    required this.id,
    required this.text,
    required this.score,
    Map<String, String> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  /// The id the record was inserted under.
  final String id;

  /// The record's text, or the matching chunk of a document. On Android,
  /// iOS and the desktops an image or audio record's text is the path it
  /// was inserted with, or its id when it came from bytes or samples alone.
  final String text;

  /// How similar the record is to the query, higher is closer.
  final double score;

  /// The key-value metadata the record was inserted with.
  final Map<String, String> metadata;

  @override
  String toString() =>
      'RetrievalRecord(id: $id, score: ${score.toStringAsFixed(4)}, '
      'text: $text, metadata: $metadata)';
}

/// Semantic Retriever's result: the nearest records, best first.
@immutable
final class RetrievalResult {
  /// Owns an unmodifiable copy of [records].
  RetrievalResult({required List<RetrievalRecord> records})
    : records = List.unmodifiable(records);

  /// The records, best first.
  final List<RetrievalRecord> records;

  @override
  String toString() => 'RetrievalResult(records: $records)';
}

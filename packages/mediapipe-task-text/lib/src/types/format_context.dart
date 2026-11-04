/// The prompt formatting Google's Text Embedder applies for models that need
/// it, such as EmbeddingGemma, named as in Google's Python API.
library;

import 'package:meta/meta.dart';

/// What an embedding is for; Google's text embedder formats the prompt to
/// match.
enum EmbeddingType {
  /// Search query.
  retrievalQuery(1),

  /// Search document, with an optional title.
  retrievalDocument(2),

  /// Sentence similarity.
  semanticSimilarity(3),

  /// Classification features.
  classification(4),

  /// Clustering features.
  clustering(5),

  /// Question or answer, selected by [TextRole].
  questionAnswering(6),

  /// Claim or evidence, selected by [TextRole].
  factChecking(7),

  /// Code query or document, selected by [TextRole].
  codeRetrieval(8);

  const EmbeddingType(this.nativeValue);

  /// The value Google's C API takes.
  final int nativeValue;
}

/// The side of a query and document pair an embedding is for.
enum TextRole {
  /// Query prompt.
  query(1),

  /// Document prompt.
  document(2);

  const TextRole(this.nativeValue);

  /// The value Google's C API takes.
  final int nativeValue;
}

/// How Google's text embedder formats one input, passed to it unchanged.
@immutable
final class TextFormatContext {
  /// Selects the embedding's [taskType], an optional document [title] and
  /// the [role] of the text.
  TextFormatContext({
    required this.taskType,
    this.title,
    this.role = TextRole.query,
  }) {
    if (title?.contains('\u0000') ?? false) {
      throw ArgumentError.value(title, 'title', 'Must not contain NUL.');
    }
  }

  /// What the embedding is for.
  final EmbeddingType taskType;

  /// Optional document title.
  final String? title;

  /// Query or document.
  final TextRole role;

  @override
  String toString() =>
      'TextFormatContext(${taskType.name}, role: ${role.name}'
      '${title == null ? '' : ', title: $title'})';
}

/// The results of every text task: immutable Dart values on core's shared
/// types, owned by the caller and valid after the task is disposed.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:meta/meta.dart';

/// The categories of every classifier head.
@immutable
final class TextClassifierResult {
  /// Owns an unmodifiable copy of [classifications].
  TextClassifierResult({
    required List<Classifications> classifications,
    this.timestampMilliseconds,
  }) : classifications = List.unmodifiable(classifications);

  /// One entry per model head, in the runtime's order.
  final List<Classifications> classifications;

  /// The stamp Google's runtime gives the request, which counts requests
  /// in steps of 1000 on its native runtime; null where the runtime reports
  /// none.
  final int? timestampMilliseconds;

  @override
  String toString() =>
      'TextClassifierResult($classifications, '
      'timestamp: $timestampMilliseconds)';
}

/// The vectors of every embedder head.
@immutable
final class TextEmbedderResult {
  /// Owns an unmodifiable copy of [embeddings].
  TextEmbedderResult({
    required List<Embedding> embeddings,
    this.timestampMilliseconds,
  }) : embeddings = List.unmodifiable(embeddings);

  /// One entry per model head, in the runtime's order.
  final List<Embedding> embeddings;

  /// The stamp Google's runtime gives the request, which counts requests
  /// in steps of 1000 on its native runtime; null where the runtime reports
  /// none.
  final int? timestampMilliseconds;

  @override
  String toString() =>
      'TextEmbedderResult($embeddings, timestamp: $timestampMilliseconds)';
}

/// One language and its probability.
@immutable
@immutable
final class LanguagePrediction {
  /// Keeps Google's output unchanged.
  const LanguagePrediction({
    required this.languageCode,
    required this.probability,
  });

  /// The language or locale code, such as `en` or `zh-Latn`.
  final String languageCode;

  /// The model's probability for it.
  final double probability;

  @override
  bool operator ==(Object other) =>
      other is LanguagePrediction &&
      other.languageCode == languageCode &&
      other.probability == probability;

  @override
  int get hashCode => Object.hash(languageCode, probability);

  @override
  String toString() => 'LanguagePrediction($languageCode, $probability)';
}

/// The languages the text may be in, most likely first.
@immutable
final class LanguageDetectorResult {
  /// Owns an unmodifiable copy of [predictions].
  LanguageDetectorResult({required List<LanguagePrediction> predictions})
    : predictions = List.unmodifiable(predictions);

  /// Predictions in the runtime's order.
  final List<LanguagePrediction> predictions;

  @override
  String toString() => 'LanguageDetectorResult($predictions)';
}

/// A correction type emitted by Google's diff implementation.
enum ProofreadingCorrectionType {
  /// Unchanged text.
  same,

  /// Inserted text.
  insertion,

  /// Deleted text.
  deletion,
}

/// One correction segment, in Google's order.
@immutable
@immutable
final class ProofreadingCorrection {
  /// Keeps Google's segment without coalescing or recomputing the diff.
  const ProofreadingCorrection({required this.type, required this.text});

  /// Unchanged, inserted or deleted text.
  final ProofreadingCorrectionType type;

  /// The segment's text.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is ProofreadingCorrection &&
      other.type == type &&
      other.text == text;

  @override
  int get hashCode => Object.hash(type, text);

  @override
  String toString() => 'ProofreadingCorrection(${type.name}, "$text")';
}

/// A completed proofreading request.
@immutable
final class TextProofreaderResult {
  /// Owns an unmodifiable copy of [corrections].
  TextProofreaderResult({
    required this.proofreadText,
    required List<ProofreadingCorrection> corrections,
  }) : corrections = List.unmodifiable(corrections);

  /// The corrected text; null if Google returned none.
  final String? proofreadText;

  /// Google's correction segments, in order.
  final List<ProofreadingCorrection> corrections;

  @override
  String toString() =>
      'TextProofreaderResult(${corrections.length} segments: $proofreadText)';
}

/// One streamed proofreading update.
@immutable
final class TextProofreaderUpdate {
  /// Owns an unmodifiable copy of [corrections].
  TextProofreaderUpdate({
    required this.chunk,
    required this.done,
    required List<ProofreadingCorrection> corrections,
  }) : corrections = List.unmodifiable(corrections);

  /// Newly generated text, not the text so far; may be null when [done].
  final String? chunk;

  /// Whether Google has completed the request.
  final bool done;

  /// Correction segments, normally delivered with the final update.
  final List<ProofreadingCorrection> corrections;

  @override
  String toString() =>
      'TextProofreaderUpdate(${done ? 'done' : 'chunk'}: $chunk)';
}

/// A completed summary.
@immutable
@immutable
final class TextSummarizerResult {
  /// Keeps Google's text, whitespace and bullet markers included.
  const TextSummarizerResult({required this.summary});

  /// The summary; null if Google returned none.
  final String? summary;

  @override
  String toString() => 'TextSummarizerResult($summary)';
}

/// One streamed summary update.
@immutable
@immutable
final class TextSummarizerUpdate {
  /// Keeps the new text and Google's completion flag.
  const TextSummarizerUpdate({required this.chunk, required this.done});

  /// Newly generated text, not the text so far; may be null when [done].
  final String? chunk;

  /// Whether Google has completed the request.
  final bool done;

  @override
  String toString() =>
      'TextSummarizerUpdate(${done ? 'done' : 'chunk'}: $chunk)';
}

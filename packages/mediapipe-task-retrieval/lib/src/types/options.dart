/// The retrieval tasks' options: core's model source and delegate plus
/// Google's embedder and retriever settings, validated the same way on every
/// platform.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

import '../../models.dart' show RetrievalModels;
import '../retrieval_tasks.dart' show UniversalEmbedder;

/// How Semantic Retriever's default chunker splits a document.
enum ChunkingMode {
  /// Chunks of `chunkSize` characters, overlapping by `chunkOverlap`.
  character,

  /// Chunks of `chunkSize` words, overlapping by `chunkOverlap`.
  word,
}

/// The data type Universal Embedder's model runs its activations in; the
/// model's own default unless set.
enum ActivationDataType {
  /// Whatever the model file specifies.
  modelDefault,

  /// 32-bit floats.
  float32,

  /// 16-bit floats.
  float16,

  /// 16-bit integers.
  int16,

  /// 8-bit integers.
  int8,
}

/// Options for Google's Universal Embedder.
final class UniversalEmbedderOptions extends TaskOptions {
  /// [l2Normalize] defaults to true, as Google's browser API does;
  /// [maxInputLength] and [visionTokensPerImage] of 0 keep the model's
  /// defaults; [cacheDir] holds compiled model artifacts between runs.
  UniversalEmbedderOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
    this.l2Normalize = true,
    this.maxInputLength = 0,
    this.visionTokensPerImage = 0,
    this.activationDataType = ActivationDataType.modelDefault,
    this.cacheDir,
  }) : super(family: 'mediapipe_retrieval', registry: RetrievalModels.byName) {
    if (maxInputLength < 0) {
      throw ArgumentError.value(
        maxInputLength,
        'maxInputLength',
        'Must be >= 0.',
      );
    }
    if (visionTokensPerImage < 0) {
      throw ArgumentError.value(
        visionTokensPerImage,
        'visionTokensPerImage',
        'Must be >= 0.',
      );
    }
    if (cacheDir case final dir? when dir.isEmpty || dir.contains('\u0000')) {
      throw ArgumentError.value(dir, 'cacheDir', 'Invalid path');
    }
  }

  /// Whether the embedding vectors are L2-normalized.
  final bool l2Normalize;

  /// The most tokens the text encoder reads, or 0 for the model's default.
  ///
  /// Google's engine reserves memory for the whole length when the task is
  /// created: with EmbeddingGemma 2 on a Mac's CPU, about 0.4 GB at the
  /// model's default and 6 GB at 4096, beyond what iOS gives an iPhone 15 Pro
  /// app (about 3.4 GB). Raise it only for longer inputs, on a device with the
  /// memory for them (upstream-issues.md UP-060).
  final int maxInputLength;

  /// The vision tokens per image, or 0 for the model's default.
  final int visionTokensPerImage;

  /// The activation data type the model runs in.
  final ActivationDataType activationDataType;

  /// A directory for compiled model artifacts, or null for none.
  final String? cacheDir;
}

/// Options for Google's Semantic Retriever: the [embedder] whose vectors it
/// indexes, where it keeps them, and how it chunks documents.
final class SemanticRetrieverOptions {
  /// [embeddingDimension] defaults to Google's 768, the EmbeddingGemma 2
  /// models' size; [chunkSize] and [chunkOverlap] to Google's 512 and 100
  /// characters. [databasePath] names a SQLite file for the index on Android,
  /// iOS, macOS, Linux and Windows, and null keeps it in memory; browsers
  /// keep it in memory only.
  SemanticRetrieverOptions({
    required this.embedder,
    this.databasePath,
    this.embeddingDimension = 768,
    this.chunkSize = 512,
    this.chunkOverlap = 100,
    this.chunkingMode = ChunkingMode.character,
  }) {
    if (embeddingDimension <= 0) {
      throw ArgumentError.value(
        embeddingDimension,
        'embeddingDimension',
        'Must be > 0.',
      );
    }
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'Must be > 0.');
    }
    if (chunkOverlap < 0 || chunkOverlap >= chunkSize) {
      throw ArgumentError.value(
        chunkOverlap,
        'chunkOverlap',
        'Must be >= 0 and < chunkSize.',
      );
    }
    if (databasePath case final path?
        when path.isEmpty || path.contains('\u0000')) {
      throw ArgumentError.value(path, 'databasePath', 'Invalid path');
    }
  }

  /// The embedder that turns records and queries into vectors.
  final UniversalEmbedder embedder;

  /// The SQLite file that holds the index, or null for memory.
  final String? databasePath;

  /// The embedder's vector size.
  final int embeddingDimension;

  /// How long each chunk of a document is, in [chunkingMode]'s units.
  final int chunkSize;

  /// How much consecutive chunks overlap.
  final int chunkOverlap;

  /// Whether chunks count characters or words.
  final ChunkingMode chunkingMode;
}

/// The options of every text task: core's model source and delegate plus
/// Google's settings, validated the same way on every platform.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show ClassifierSettings, checkClassifierSettings;

import '../../models.dart' show TextModels;

const _family = 'mediapipe_text';

/// Options for Google's Text Classifier.
final class TextClassifierOptions extends TaskOptions
    implements ClassifierSettings {
  /// Defaults match Google's: every category, no threshold.
  TextClassifierOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
    this.displayNamesLocale,
    this.maxResults = -1,
    this.scoreThreshold = 0,
    List<String>? categoryAllowlist,
    List<String>? categoryDenylist,
  }) : categoryAllowlist = List.unmodifiable(categoryAllowlist ?? const []),
       categoryDenylist = List.unmodifiable(categoryDenylist ?? const []),
       super(family: _family, registry: TextModels.byName) {
    checkClassifierSettings(this);
  }

  /// Locale of the display names in the model metadata.
  @override
  final String? displayNamesLocale;

  /// Maximum categories per head; negative returns all of them.
  @override
  final int maxResults;

  /// Categories scoring below this are dropped.
  @override
  final double scoreThreshold;

  /// Category names to keep; exclusive with [categoryDenylist].
  @override
  final List<String> categoryAllowlist;

  /// Category names to drop; exclusive with [categoryAllowlist].
  @override
  final List<String> categoryDenylist;
}

/// Options for Google's Language Detector.
final class LanguageDetectorOptions extends TaskOptions
    implements ClassifierSettings {
  /// Defaults match Google's Python and C APIs: every language, no
  /// threshold. (Its browser and mobile SDKs apply the model's own threshold
  /// when none is set; this package always sends one, so every platform
  /// answers alike.)
  LanguageDetectorOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
    this.displayNamesLocale,
    this.maxResults = -1,
    this.scoreThreshold = 0,
    List<String>? categoryAllowlist,
    List<String>? categoryDenylist,
  }) : categoryAllowlist = List.unmodifiable(categoryAllowlist ?? const []),
       categoryDenylist = List.unmodifiable(categoryDenylist ?? const []),
       super(family: _family, registry: TextModels.byName) {
    checkClassifierSettings(this);
  }

  /// Locale of the display names in the model metadata.
  @override
  final String? displayNamesLocale;

  /// Maximum languages; negative returns all of them.
  @override
  final int maxResults;

  /// Languages scoring below this are dropped.
  @override
  final double scoreThreshold;

  /// Language codes to keep; exclusive with [categoryDenylist].
  @override
  final List<String> categoryAllowlist;

  /// Language codes to drop; exclusive with [categoryAllowlist].
  @override
  final List<String> categoryDenylist;
}

/// Options for Google's Text Embedder, which also runs EmbeddingGemma
/// (`TextModels.embeddingGemma`).
final class TextEmbedderOptions extends TaskOptions {
  /// Google's graph handles normalization and quantization.
  TextEmbedderOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
    this.l2Normalize = false,
    this.quantize = false,
  }) : super(family: _family, registry: TextModels.byName);

  /// Normalize vectors with the L2 norm when the model does not already.
  final bool l2Normalize;

  /// Return scalar-quantized bytes instead of float vectors.
  final bool quantize;
}

/// Options for Google's Proofreader, a large `.litertlm` model read from a
/// file: supply [model] or [modelPath], not [modelBytes].
final class TextProofreaderOptions extends TaskOptions {
  /// Null or zero [maxNumTokens] keeps the model's own budget, and a null
  /// [cacheDirectory] keeps Google's default.
  TextProofreaderOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
    this.maxNumTokens,
    this.cacheDirectory,
  }) : super(family: _family, registry: TextModels.byName) {
    _checkGenerativeOptions('TextProofreader', this);
  }

  /// Input and output token budget; null or zero keeps Google's default.
  final int? maxNumTokens;

  /// Where Google's runtime caches the prepared model; null keeps its
  /// default, beside the model.
  final String? cacheDirectory;
}

/// Summarization modes Google's Summarizer model was trained for.
enum TextSummarizerMode {
  /// A short summary paragraph.
  tldr,

  /// A bulleted list of key points; Google's default.
  keypoints,
}

/// Options for Google's Summarizer, a large `.litertlm` model read from a
/// file: supply [model] or [modelPath], not [modelBytes].
final class TextSummarizerOptions extends TaskOptions {
  /// The [mode] is fixed for the task's lifetime. Null or zero
  /// [maxNumTokens] keeps the model's own budget, and a null
  /// [cacheDirectory] keeps Google's default.
  TextSummarizerOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
    this.mode = TextSummarizerMode.keypoints,
    this.maxNumTokens,
    this.cacheDirectory,
  }) : super(family: _family, registry: TextModels.byName) {
    _checkGenerativeOptions('TextSummarizer', this);
  }

  /// Paragraph or key points; no prompt is added in Dart.
  final TextSummarizerMode mode;

  /// Input and output token budget; null or zero keeps Google's default.
  final int? maxNumTokens;

  /// Where Google's runtime caches the prepared model; null keeps its
  /// default, beside the model.
  final String? cacheDirectory;
}

void _checkGenerativeOptions(String task, TaskOptions options) {
  final (tokens, cache) = switch (options) {
    final TextProofreaderOptions o => (o.maxNumTokens, o.cacheDirectory),
    final TextSummarizerOptions o => (o.maxNumTokens, o.cacheDirectory),
    _ => (null, null),
  };
  if (options.modelBytes != null) {
    throw ArgumentError(
      '$task reads its model from a file: supply model or modelPath, not '
      'modelBytes.',
    );
  }
  if (tokens != null && (tokens < 0 || tokens > 0x7fffffff)) {
    throw ArgumentError.value(
      tokens,
      'maxNumTokens',
      'Must fit a nonnegative int32.',
    );
  }
  if (cache != null && (cache.isEmpty || cache.contains('\u0000'))) {
    throw ArgumentError.value(
      cache,
      'cacheDirectory',
      'Expected a nonempty path without NUL.',
    );
  }
}

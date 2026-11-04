/// Browsers have no native runtime: the classic tasks and EmbeddingGemma run
/// through the registered browser plugin, so reaching these means it did not
/// register, and the generative tasks' capability queries refuse browsers
/// first (upstream-issues.md UP-034).
library;

import 'package:mediapipe_core/platform_interface.dart'
    show pluginNotRegistered;

import '../types/options.dart';
import '../types/results.dart';
import 'text_task_runner.dart';

Never _unavailable() => throw pluginNotRegistered('mediapipe_text');

/// The native Text Classifier; browsers have none.
Future<TextTaskRunner<String, TextClassifierResult>> openNativeTextClassifier(
  TextClassifierOptions options,
) async => _unavailable();

/// The native Language Detector; browsers have none.
Future<TextTaskRunner<String, LanguageDetectorResult>>
openNativeLanguageDetector(LanguageDetectorOptions options) async =>
    _unavailable();

/// The native Text Embedder; browsers have none.
Future<TextTaskRunner<TextEmbedderInput, TextEmbedderResult>>
openNativeTextEmbedder(TextEmbedderOptions options) async => _unavailable();

/// The native Proofreader; browsers have none.
Future<TextStreamRunner<String, TextProofreaderResult, TextProofreaderUpdate>>
openNativeTextProofreader(TextProofreaderOptions options) async =>
    _unavailable();

/// The native Summarizer; browsers have none.
Future<TextStreamRunner<String, TextSummarizerResult, TextSummarizerUpdate>>
openNativeTextSummarizer(TextSummarizerOptions options) async => _unavailable();

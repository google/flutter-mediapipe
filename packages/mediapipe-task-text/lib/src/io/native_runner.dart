/// Google's native text runtime: each task on its own worker isolate.
library;

import 'package:mediapipe_core/task_worker.dart';

import '../runner/text_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'classic_text_runtime.dart';
import 'native_language_detector.dart';
import 'native_text_classifier.dart';
import 'native_text_embedder.dart';
import 'native_text_proofreader.dart';
import 'native_text_summarizer.dart';

/// Opens Google's Text Classifier on a worker.
Future<TextTaskRunner<String, TextClassifierResult>> openNativeTextClassifier(
  TextClassifierOptions options,
) => _open('TextClassifier', options, NativeTextClassifier.new);

/// Opens Google's Language Detector on a worker.
Future<TextTaskRunner<String, LanguageDetectorResult>>
openNativeLanguageDetector(LanguageDetectorOptions options) =>
    _open('LanguageDetector', options, NativeLanguageDetector.new);

/// Opens Google's Text Embedder on a worker.
Future<TextTaskRunner<TextEmbedderInput, TextEmbedderResult>>
openNativeTextEmbedder(TextEmbedderOptions options) =>
    _open('TextEmbedder', options, NativeTextEmbedder.new);

/// Opens Google's Proofreader on a worker.
Future<TextStreamRunner<String, TextProofreaderResult, TextProofreaderUpdate>>
openNativeTextProofreader(TextProofreaderOptions options) =>
    _open('TextProofreader', options, NativeTextProofreader.new);

/// Opens Google's Summarizer on a worker.
Future<TextStreamRunner<String, TextSummarizerResult, TextSummarizerUpdate>>
openNativeTextSummarizer(TextSummarizerOptions options) =>
    _open('TextSummarizer', options, NativeTextSummarizer.new);

/// Starts the task [create] makes from [options] on its own worker, once
/// this platform has Google's text library.
Future<_TextWorker<I, R, U>> _open<I extends Object, R, U, O>(
  String name,
  O options,
  WorkerTask<I, R, U> Function(O) create,
) {
  requireTextTasksRuntime();
  final worker = _TextWorker<I, R, U>(name);
  return worker.start(options, create).then((_) => worker);
}

/// A text task on its own worker isolate, as text's runners call it.
final class _TextWorker<I extends Object, R, U> extends TaskWorker<I, R, U>
    implements TextStreamRunner<I, R, U> {
  _TextWorker(super.name);
}

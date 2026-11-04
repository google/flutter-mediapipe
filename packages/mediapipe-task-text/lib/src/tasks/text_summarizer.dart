import 'package:mediapipe_core/mediapipe_core.dart';

import '../capabilities.dart';
import '../runner/native_tasks.dart';
import '../runner/text_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';

/// Google's Summarizer: a paragraph or key points for a text.
///
/// One class on every platform. Google's native runtime serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; Google's browser
/// runtime has no Summarizer, which `queryTextSummarizerCapabilities()`
/// reports, and there [create] throws [RuntimeUnavailableException].
///
/// ```dart
/// final task = await TextSummarizer.create(
///   TextSummarizerOptions(model: TextModels.summarizer),
/// );
/// final result = await task.summarize('A long text.');
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class TextSummarizer {
  TextSummarizer._(this._task, this._runner, this.delegate, this.mode);
  final TextTaskSession<String, TextSummarizerResult> _task;
  final TextStreamRunner<String, TextSummarizerResult, TextSummarizerUpdate>
  _runner;

  /// The processor the task runs on, fixed at creation.
  final Delegate delegate;

  /// The summarization mode, fixed at creation; create another task to
  /// switch.
  final TextSummarizerMode mode;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<TextSummarizer> create(TextSummarizerOptions options) async {
    final runner = await openGenerativeTextTask(
      options,
      capabilities: queryTextSummarizerCapabilities,
      native: openNativeTextSummarizer,
    );
    return TextSummarizer._(
      TextTaskSession('TextSummarizer', runner),
      runner,
      options.delegate,
      options.mode,
    );
  }

  /// Summarizes [text] and returns Google's text unchanged.
  Future<TextSummarizerResult> summarize(String text) => _task.run(text, text);

  /// Streams new text for [text] as Google generates it. Starts on listen;
  /// the stream has one subscription. Cancelling stops delivery and waits
  /// for Google's generation to finish, since it cannot be cancelled.
  /// Pausing buffers updates; it does not pause generation.
  Stream<TextSummarizerUpdate> summarizeStream(String text) {
    try {
      _task.check(text);
      return _runner.stream(text);
    } catch (error, stack) {
      return Stream.error(error, stack);
    }
  }

  /// Finishes accepted work and active streams and releases Google's task.
  /// Repeated calls return the same completion; any other call afterwards
  /// fails with [StateError].
  Future<void> dispose() => _task.dispose();
}

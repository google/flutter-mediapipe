import 'package:mediapipe_core/mediapipe_core.dart';

import '../capabilities.dart';
import '../runner/native_tasks.dart';
import '../runner/text_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';

/// Google's Proofreader: corrected text and the edits that make it.
///
/// One class on every platform. Google's native runtime serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; Google's browser
/// runtime has no Proofreader, which `queryTextProofreaderCapabilities()`
/// reports, and there [create] throws [RuntimeUnavailableException].
///
/// ```dart
/// final task = await TextProofreader.create(
///   TextProofreaderOptions(model: TextModels.proofreader),
/// );
/// final result = await task.proofread('Their is a error.');
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class TextProofreader {
  TextProofreader._(this._task, this._runner, this.delegate);
  final TextTaskSession<String, TextProofreaderResult> _task;
  final TextStreamRunner<String, TextProofreaderResult, TextProofreaderUpdate>
  _runner;

  /// The processor the task runs on, fixed at creation.
  final Delegate delegate;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<TextProofreader> create(TextProofreaderOptions options) async {
    final runner = await openGenerativeTextTask(
      options,
      capabilities: queryTextProofreaderCapabilities,
      native: openNativeTextProofreader,
    );
    return TextProofreader._(
      TextTaskSession('TextProofreader', runner),
      runner,
      options.delegate,
    );
  }

  /// Corrects [text] and returns Google's corrected text and its edits.
  Future<TextProofreaderResult> proofread(String text) => _task.run(text, text);

  /// Streams Google's updates for [text]: new text as it is generated, and
  /// the corrections with the final update. Starts on listen; the stream
  /// has one subscription. Cancelling stops delivery and waits for Google's
  /// generation to finish, since it cannot be cancelled. Pausing buffers
  /// updates; it does not pause generation.
  Stream<TextProofreaderUpdate> proofreadStream(String text) {
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

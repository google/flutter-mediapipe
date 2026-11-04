import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show classifierSettingsJson;

import '../capabilities.dart';
import '../results/decoders.dart';
import '../runner/native_tasks.dart';
import '../runner/text_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';

/// Google's Text Classifier: the categories of every model head.
///
/// One class on every platform. Google's native runtime serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; its browser
/// runtime serves it through the registered web plugin.
///
/// ```dart
/// final task = await TextClassifier.create(
///   TextClassifierOptions(model: TextModels.bertClassifier),
/// );
/// final result = await task.classify('Hello');
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class TextClassifier {
  TextClassifier._(this._task, this.delegate);
  final TextTaskSession<String, TextClassifierResult> _task;

  /// The processor the task runs on, fixed at creation.
  final Delegate delegate;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<TextClassifier> create(TextClassifierOptions options) async =>
      TextClassifier._(
        TextTaskSession(
          'TextClassifier',
          await openClassicTextTask(
            options,
            capabilities: queryTextClassifierCapabilities,
            task: 'text_classifier',
            settings: classifierSettingsJson(options),
            decode: decodeTextClassifierResult,
            request: (String text) => (text, const {}),
            native: openNativeTextClassifier,
          ),
        ),
        options.delegate,
      );

  /// Classifies [text] with Google's tokenizer, model and postprocessing.
  Future<TextClassifierResult> classify(String text) => _task.run(text, text);

  /// Finishes accepted work and releases Google's task. Repeated calls return
  /// the same completion; any other call afterwards throws [StateError].
  Future<void> dispose() => _task.dispose();
}

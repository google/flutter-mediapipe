import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show classifierSettingsJson;

import '../capabilities.dart';
import '../results/decoders.dart';
import '../runner/native_tasks.dart';
import '../runner/text_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';

/// Google's Language Detector: the languages a text may be in.
///
/// One class on every platform. Google's native runtime serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; its browser
/// runtime serves it through the registered web plugin.
///
/// ```dart
/// final task = await LanguageDetector.create(
///   LanguageDetectorOptions(model: TextModels.languageDetector),
/// );
/// final result = await task.detect('Bonjour');
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class LanguageDetector {
  LanguageDetector._(this._task, this.delegate);
  final TextTaskSession<String, LanguageDetectorResult> _task;

  /// The processor the task runs on, fixed at creation.
  final Delegate delegate;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<LanguageDetector> create(
    LanguageDetectorOptions options,
  ) async => LanguageDetector._(
    TextTaskSession(
      'LanguageDetector',
      await openClassicTextTask(
        options,
        capabilities: queryLanguageDetectorCapabilities,
        task: 'language_detector',
        settings: classifierSettingsJson(options),
        decode: decodeLanguageDetectorResult,
        request: (String text) => (text, const {}),
        native: openNativeLanguageDetector,
      ),
    ),
    options.delegate,
  );

  /// Detects the languages [text] may be in, most likely first.
  Future<LanguageDetectorResult> detect(String text) => _task.run(text, text);

  /// Finishes accepted work and releases Google's task. Repeated calls return
  /// the same completion; any other call afterwards throws [StateError].
  Future<void> dispose() => _task.dispose();
}

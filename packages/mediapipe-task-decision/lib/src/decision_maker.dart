import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import 'capabilities.dart';
import 'decision_backend.dart';
import 'results/decoders.dart';
import 'runner/native_tasks.dart';
import 'types/options.dart';
import 'types/questions.dart';
import 'types/results.dart';

/// Google's Decision Maker: answers yes-or-no, choice and score questions
/// about a text with calibrated probabilities, in one forward pass of a
/// small model rather than by generating text.
///
/// One class on every platform. Google's library serves it on a worker
/// isolate on Android, iOS, macOS, Linux and Windows; its browser runtime
/// serves it through the registered web plugin.
///
/// ```dart
/// final task = await DecisionMaker.create(
///   DecisionMakerOptions(model: DecisionModels.layaS256),
/// );
/// final refund = await task.evaluateBoolean(
///   'My order arrived broken and I want my money back.',
///   BooleanQuestion('The customer wants a refund.'),
/// );
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class DecisionMaker {
  DecisionMaker._(this._backend, this.delegate);

  final DecisionBackend _backend;
  final _queue = SerialTaskQueue('DecisionMaker');

  /// The processor the task runs on, fixed at creation.
  final Delegate delegate;

  /// Resolves the model and opens Google's task off the calling isolate. A
  /// pinned model Google's runtime here cannot run is refused before any
  /// download, with `queryDecisionMakerCapabilities(model)`'s reason.
  static Future<DecisionMaker> create(DecisionMakerOptions options) async {
    requireDelegate(
      await queryDecisionMakerCapabilities(options.model),
      options.delegate,
    );
    await resolveTaskModel(options);
    final DecisionBackend backend;
    if (decisionBackendFactory case final factory?) {
      try {
        backend = await factory({
          'modelBytes': options.modelBytes,
          'modelPath': options.modelPath,
          'delegate': options.delegate.name.toUpperCase(),
          // Unset, Google's browser runtime keeps the model's budget.
          'maxNumTokens': options.maxNumTokens == 0
              ? null
              : options.maxNumTokens,
        });
      } catch (error) {
        throw taskException(error);
      }
    } else {
      backend = await openNativeDecisionMaker(options);
    }
    return DecisionMaker._(backend, options.delegate);
  }

  /// Whether [question]'s condition holds for [text].
  Future<BooleanResult> evaluateBoolean(
    String text,
    BooleanQuestion question,
  ) async => decodeBooleanResult(
    await _run({
      'method': 'boolean',
      'text': _checked(text),
      'question': question.toJson(),
    }),
  );

  /// Which of [question]'s options fits [text].
  Future<ChoiceResult> evaluateChoice(
    String text,
    ChoiceQuestion question,
  ) async => decodeChoiceResult(
    await _run({
      'method': 'choice',
      'text': _checked(text),
      'question': question.toJson(),
    }),
    question,
  );

  /// Where [text] falls on [question]'s rubric.
  Future<ScoreResult> evaluateScore(
    String text,
    ScoreQuestion question,
  ) async => decodeScoreResult(
    await _run({
      'method': 'score',
      'text': _checked(text),
      'question': question.toJson(),
    }),
  );

  /// [evaluateBoolean] for each of [texts] in one call, which Google's
  /// engine batches; [sharedPrefix] is text every input starts with.
  Future<List<BooleanResult>> evaluateBooleanBatch(
    List<String> texts,
    BooleanQuestion question, {
    String? sharedPrefix,
  }) async => texts.isEmpty
      ? const []
      : decodeBatch(
          await _run(_batch('booleanBatch', texts, question, sharedPrefix)),
          decodeBooleanResult,
        );

  /// [evaluateChoice] for each of [texts] in one call.
  Future<List<ChoiceResult>> evaluateChoiceBatch(
    List<String> texts,
    ChoiceQuestion question, {
    String? sharedPrefix,
  }) async => texts.isEmpty
      ? const []
      : decodeBatch(
          await _run(_batch('choiceBatch', texts, question, sharedPrefix)),
          (json) => decodeChoiceResult(json, question),
        );

  /// [evaluateScore] for each of [texts] in one call.
  Future<List<ScoreResult>> evaluateScoreBatch(
    List<String> texts,
    ScoreQuestion question, {
    String? sharedPrefix,
  }) async => texts.isEmpty
      ? const []
      : decodeBatch(
          await _run(_batch('scoreBatch', texts, question, sharedPrefix)),
          decodeScoreResult,
        );

  /// Finishes accepted work and releases Google's task. Repeated calls return
  /// the same completion; any other call afterwards throws [StateError].
  Future<void> dispose() => _queue.close(_backend.dispose);

  Map<String, Object?> _batch(
    String method,
    List<String> texts,
    Object question,
    String? sharedPrefix,
  ) => {
    'method': method,
    'texts': [for (final text in texts) _checked(text)],
    'question': switch (question) {
      BooleanQuestion q => q.toJson(),
      ChoiceQuestion q => q.toJson(),
      ScoreQuestion q => q.toJson(),
      _ => throw ArgumentError.value(question, 'question'),
    },
    'sharedPrefix': sharedPrefix == null ? null : _checked(sharedPrefix),
  };

  /// Runs [request] after every request accepted before it.
  Future<Object?> _run(Map<String, Object?> request) =>
      _queue.add(() => _backend.run(request));
}

/// Google's C API reads NUL-terminated strings.
String _checked(String text) {
  if (text.contains('\u0000')) {
    throw ArgumentError.value(text, 'text', 'Must not contain NUL.');
  }
  return text;
}

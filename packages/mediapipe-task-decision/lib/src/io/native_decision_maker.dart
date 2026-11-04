import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart'
    show checkNativeStatus, fillBaseOptions, nativeString;
import 'package:mediapipe_core/platform_interface.dart';
import 'package:mediapipe_core/task_worker.dart';

import '../capabilities.dart';
import '../types/options.dart';
import 'third_party/mediapipe/decision_bindings.dart' as mp;

/// This process's target, as [decisionRuntimeTargets] names it.
final _target =
    '${Platform.operatingSystem}/${Abi.current().toString().split('_').last}';

/// Fails before a worker starts where no library with Decision Maker was
/// bundled.
void requireDecisionRuntime() {
  if (!decisionRuntimeTargets.containsKey(_target)) {
    throw RuntimeUnavailableException(
      "Google's Decision Maker library is unavailable on this platform.",
      fix:
          "Google's Decision Maker library covers "
          '${decisionRuntimeTargets.keys.join(', ')}, and browsers run its '
          'JavaScript runtime.',
    );
  }
  try {
    Native.addressOf<
      NativeFunction<
        Int32 Function(
          Pointer<mp.MpDecisionMakerOptions>,
          Pointer<Pointer<Void>>,
          Pointer<Pointer<Char>>,
        )
      >
    >(mp.create);
  } catch (error) {
    if (missingLinuxGraphicsLibraries('$error') case final missing?) {
      throw missing;
    }
    throw RuntimeUnavailableException(
      "Google's Decision Maker library is unavailable.",
      fix: tasksRuntimeUnavailable('Decision Maker', Platform.operatingSystem),
    );
  }
}

/// Google's Decision Maker, created, used and closed on one worker isolate.
/// Requests and results are the JSON shapes of Google's JavaScript API, so
/// both runtimes share one decoder.
final class NativeDecisionMaker
    extends WorkerTask<Map<String, Object?>, Object?, Never> {
  /// Loads Google's task and acquires its handle.
  NativeDecisionMaker(DecisionMakerOptions options) {
    using((arena) {
      final native = arena<mp.MpDecisionMakerOptions>();
      fillBaseOptions(
        native.ref.baseOptions,
        arena,
        modelPath: options.modelPath,
        modelBytes: options.modelBytes,
      );
      // 0 keeps the model's budget, as Google's header defines it.
      native.ref.maxNumTokens = options.maxNumTokens;
      final output = arena<Pointer<Void>>();
      _check((error) => mp.create(native, output, error));
      _handle = output.value;
      if (_handle == nullptr) {
        throw StateError('MediaPipe returned no DecisionMaker.');
      }
    });
  }

  Pointer<Void> _handle = nullptr;

  /// Runs one request (see `DecisionBackend.run`).
  @override
  Object? run(Map<String, Object?> request) {
    if (_handle == nullptr) throw StateError('DecisionMaker has been closed.');
    final question = request['question']! as Map<String, Object?>;
    return using((arena) {
      Pointer<Char> string(String? value) =>
          value == null ? nullptr : value.toNativeUtf8(allocator: arena).cast();
      Pointer<Pointer<Char>> strings(List<String> values) {
        final array = arena<Pointer<Char>>(values.length);
        for (var i = 0; i < values.length; i++) {
          array[i] = string(values[i]);
        }
        return array;
      }

      final method = request['method']! as String;
      final texts = method.endsWith('Batch')
          ? (request['texts']! as List).cast<String>()
          : [request['text']! as String];
      final prefix = string(request['sharedPrefix'] as String?);
      final temperature = (question['temperature'] as num?)?.toDouble() ?? 0;
      switch (method) {
        case 'boolean' || 'booleanBatch':
          final q = arena<mp.MpBooleanQuestion>();
          q.ref
            ..condition = string(question['condition']! as String)
            ..threshold = (question['threshold']! as num).toDouble()
            ..temperature = temperature
            ..normalizePrior = question['normalizePrior']! as bool;
          final results = arena<mp.MpBooleanResult>(texts.length);
          if (method == 'boolean') {
            _check(
              (e) =>
                  mp.evaluateBoolean(_handle, string(texts[0]), q, results, e),
            );
            return _boolean(results.ref);
          }
          _check(
            (e) => mp.evaluateBooleanBatch(
              _handle,
              prefix,
              strings(texts),
              texts.length,
              q,
              results,
              e,
            ),
          );
          return [for (var i = 0; i < texts.length; i++) _boolean(results[i])];
        case 'choice' || 'choiceBatch':
          final criteria = (question['criteria']! as Map)
              .cast<String, String>();
          final q = arena<mp.MpChoiceQuestion>();
          q.ref
            ..keys = strings(criteria.keys.toList())
            ..descriptions = strings(criteria.values.toList())
            ..count = criteria.length
            ..temperature = temperature
            ..instructions = string(question['instructions'] as String?)
            ..scoringMode = question['scoringMode']! as int
            ..normalizePrior = question['normalizePrior']! as bool;
          final results = arena<mp.MpChoiceResult>(texts.length);
          if (method == 'choice') {
            _check(
              (e) =>
                  mp.evaluateChoice(_handle, string(texts[0]), q, results, e),
            );
            try {
              return _choice(results.ref);
            } finally {
              mp.closeChoiceResult(results);
            }
          }
          _check(
            (e) => mp.evaluateChoiceBatch(
              _handle,
              prefix,
              strings(texts),
              texts.length,
              q,
              results,
              e,
            ),
          );
          try {
            return [for (var i = 0; i < texts.length; i++) _choice(results[i])];
          } finally {
            mp.closeChoiceResultBatch(results, texts.length);
          }
        case 'score' || 'scoreBatch':
          final rubric = (question['rubric']! as List).cast<String>();
          final q = arena<mp.MpScoreQuestion>();
          q.ref
            ..rubric = strings(rubric)
            ..count = rubric.length
            ..temperature = temperature
            ..instructions = string(question['instructions'] as String?);
          final results = arena<mp.MpScoreResult>(texts.length);
          if (method == 'score') {
            _check(
              (e) => mp.evaluateScore(_handle, string(texts[0]), q, results, e),
            );
            try {
              return _score(results.ref);
            } finally {
              mp.closeScoreResult(results);
            }
          }
          _check(
            (e) => mp.evaluateScoreBatch(
              _handle,
              prefix,
              strings(texts),
              texts.length,
              q,
              results,
              e,
            ),
          );
          try {
            return [for (var i = 0; i < texts.length; i++) _score(results[i])];
          } finally {
            mp.closeScoreResultBatch(results, texts.length);
          }
      }
      throw ArgumentError.value(method, 'method');
    });
  }

  /// Releases Google's task; later calls do nothing.
  @override
  void close() {
    if (_handle == nullptr) return;
    final task = _handle;
    _handle = nullptr;
    _check((error) => mp.close(task, error));
  }
}

Map<String, Object?> _boolean(mp.MpBooleanResult result) => {
  'value': result.value,
  'probabilityTrue': result.probabilityTrue,
  'confidence': result.confidence,
};

Map<String, Object?> _choice(mp.MpChoiceResult result) => {
  'selectedKey': nativeString(result.selectedKey) ?? '',
  'probabilities': {
    for (var i = 0; i < result.count; i++)
      nativeString(result.keys[i])!: result.probabilities[i],
  },
  'confidence': result.confidence,
};

Map<String, Object?> _score(mp.MpScoreResult result) => {
  'expectedScore': result.expectedScore,
  'probabilities': [
    for (var i = 0; i < result.count; i++) result.probabilities[i],
  ],
  'confidence': result.confidence,
  'selectedKey': nativeString(result.selectedKey) ?? '',
};

/// Frees Google's error string on success and failure alike.
void _check(int Function(Pointer<Pointer<Char>>) call) =>
    checkNativeStatus(call, mp.errorFree);

@TestOn('vm')
@Tags(['native-assets'])
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:mediapipe_decision/mediapipe_decision.dart';
import 'package:test/test.dart';

/// Google's Laya model; `make models_decision` downloads it.
final _laya =
    Platform.environment['MEDIAPIPE_DECISION_MODEL'] ?? 'models/laya_s256.task';

/// Google's text and vision EmbeddingGemma 2 (388 MB) and its text-only
/// one (165 MB), when set: the two share a text encoder, so the same cases
/// check both against Google's Python answers, locally; CI downloads Laya
/// alone.
final _gemmas = {
  'EmbeddingGemma 2': Platform.environment['MEDIAPIPE_DECISION_EG2_MODEL'],
  'EmbeddingGemma 2 text':
      Platform.environment['MEDIAPIPE_DECISION_EG2_TEXT_MODEL'],
};

final _host =
    '${Platform.operatingSystem}/${Abi.current().toString().split('_').last}';

String? _missing(String model, String name) =>
    File(model).existsSync() ? null : 'No $name model at $model.';

void main() {
  final laya = _missing(_laya, 'Laya');
  _suite('Laya', _laya, 'laya_s256_reference.json', laya);
  for (final MapEntry(key: name, value: gemma) in _gemmas.entries) {
    if (gemma == null) continue;
    _suite(
      name,
      gemma,
      'embedding_gemma_2_text_vision_reference.json',
      _missing(gemma, name),
    );
  }

  test('a disposed task refuses requests', skip: laya, () async {
    final other = await DecisionMaker.create(
      DecisionMakerOptions(modelPath: _laya),
    );
    await other.dispose();
    await other.dispose();
    expect(
      () => other.evaluateBoolean('text', BooleanQuestion('A condition.')),
      throwsStateError,
    );
  });

  test('Google\'s failures are TaskExceptions', () async {
    await expectLater(
      DecisionMaker.create(
        DecisionMakerOptions(modelPath: '/nonexistent/laya_s256.task'),
      ),
      throwsA(isA<TaskException>()),
    );
  });
}

/// Every reference case on [model] against Google's answers from its own
/// Python API in `test/fixtures/`[fixture] (tool/generate_reference.py).
void _suite(String label, String model, String fixture, String? absent) {
  final answers =
      jsonDecode(File('test/fixtures/$fixture').readAsStringSync())
          as Map<String, Object?>;
  // The references come from Google's wheel on macOS arm64, where Google's
  // per-family library answers to float32 precision; another host's build of
  // Google's library may differ slightly.
  final tolerance = _host == 'macos/arm64' ? 1e-6 : 0.02;
  late DecisionMaker task;

  setUpAll(() async {
    if (absent != null) return;
    task = await DecisionMaker.create(DecisionMakerOptions(modelPath: model));
  });
  tearDownAll(() async {
    if (absent == null) await task.dispose();
  });

  for (final raw in answers['cases']! as List) {
    final reference = raw as Map<String, Object?>;
    final name = reference['name']! as String;
    final texts = (reference['texts']! as List).cast<String>();
    final expected = (reference['results']! as List)
        .cast<Map<String, Object?>>();
    final json = reference['question']! as Map<String, Object?>;
    test('$label: $name matches Google\'s Python API', skip: absent, () async {
      switch (reference['kind']) {
        case 'boolean':
          final question = BooleanQuestion(
            json['condition']! as String,
            threshold: (json['threshold']! as num).toDouble(),
            normalizePrior: json['normalizePrior']! as bool,
          );
          final batch = await task.evaluateBooleanBatch(texts, question);
          for (var i = 0; i < texts.length; i++) {
            for (final result in [
              await task.evaluateBoolean(texts[i], question),
              batch[i],
            ]) {
              expect(result.value, expected[i]['value']);
              _near(
                result.probabilityTrue,
                expected[i]['probabilityTrue'],
                tolerance,
              );
              _near(result.confidence, expected[i]['confidence'], tolerance);
            }
          }
        case 'choice':
          final question = ChoiceQuestion(
            (json['criteria']! as Map).cast<String, String>(),
            instructions: json['instructions'] as String?,
          );
          final batch = await task.evaluateChoiceBatch(texts, question);
          for (var i = 0; i < texts.length; i++) {
            for (final result in [
              await task.evaluateChoice(texts[i], question),
              batch[i],
            ]) {
              final want = expected[i];
              expect(result.selectedKey, want['selectedKey']);
              expect(
                result.probabilities.keys,
                question.criteria.keys,
                reason: 'probabilities come in the question\'s order',
              );
              final probabilities = want['probabilities']! as Map;
              for (final key in question.criteria.keys) {
                _near(
                  result.probabilities[key]!,
                  probabilities[key],
                  tolerance,
                );
              }
              _near(result.confidence, want['confidence'], tolerance);
              expect(result.predictionSet, want['predictionSet']);
            }
          }
        case 'score':
          final question = ScoreQuestion(
            (json['rubric']! as List).cast<String>(),
            instructions: json['instructions'] as String?,
          );
          final batch = await task.evaluateScoreBatch(texts, question);
          for (var i = 0; i < texts.length; i++) {
            for (final result in [
              await task.evaluateScore(texts[i], question),
              batch[i],
            ]) {
              final want = expected[i];
              _near(result.expectedScore, want['expectedScore'], tolerance);
              final probabilities = want['probabilities']! as List;
              expect(result.probabilities, hasLength(probabilities.length));
              for (var j = 0; j < probabilities.length; j++) {
                _near(result.probabilities[j], probabilities[j], tolerance);
              }
              _near(result.confidence, want['confidence'], tolerance);
              expect(result.selectedKey, want['selectedKey']);
            }
          }
      }
    });
  }
}

void _near(double actual, Object? expected, double tolerance) =>
    expect(actual, closeTo((expected! as num).toDouble(), tolerance));

/// Results from the JSON both runtimes answer in: Google's JavaScript result
/// objects in browsers, and the same shapes from the native worker.
library;

import '../types/questions.dart';
import '../types/results.dart';

/// A [BooleanResult] from Google's `{value, probabilityTrue, confidence}`.
BooleanResult decodeBooleanResult(Object? json) {
  final map = json! as Map;
  return BooleanResult(
    value: map['value']! as bool,
    probabilityTrue: _number(map['probabilityTrue']),
    confidence: _number(map['confidence']),
  );
}

/// A [ChoiceResult] from Google's `{selectedKey, probabilities,
/// confidence}`, its probabilities in [question]'s order whatever order the
/// runtime returned them in.
ChoiceResult decodeChoiceResult(Object? json, ChoiceQuestion question) {
  final map = json! as Map;
  final probabilities = (map['probabilities']! as Map).map(
    (key, value) => MapEntry(key as String, _number(value)),
  );
  return ChoiceResult(
    selectedKey: map['selectedKey']! as String,
    probabilities: {
      for (final key in question.criteria.keys) key: probabilities[key] ?? 0,
    },
    confidence: _number(map['confidence']),
  );
}

/// A [ScoreResult] from Google's `{expectedScore, probabilities, confidence,
/// selectedKey}`.
ScoreResult decodeScoreResult(Object? json) {
  final map = json! as Map;
  return ScoreResult(
    expectedScore: _number(map['expectedScore']),
    probabilities: [
      for (final value in map['probabilities']! as List) _number(value),
    ],
    confidence: _number(map['confidence']),
    selectedKey: (map['selectedKey'] as String?) ?? '',
  );
}

/// One result per input of a batch, decoded by [decode].
List<R> decodeBatch<R>(Object? json, R Function(Object? json) decode) => [
  for (final item in json! as List) decode(item),
];

double _number(Object? value) => (value! as num).toDouble();

/// Decision Maker's answers: the same plain values on every platform.
library;

/// The answer to a `BooleanQuestion`.
final class BooleanResult {
  /// Google's answer, its probability and its confidence.
  const BooleanResult({
    required this.value,
    required this.probabilityTrue,
    required this.confidence,
  });

  /// Whether the condition holds: [probabilityTrue] reached the question's
  /// threshold.
  final bool value;

  /// Calibrated probability that the condition holds, in `[0, 1]`.
  final double probabilityTrue;

  /// How certain the answer is relative to the threshold, in `[0, 1]`.
  final double confidence;

  @override
  String toString() =>
      'BooleanResult($value, probabilityTrue: $probabilityTrue, '
      'confidence: $confidence)';
}

/// The answer to a `ChoiceQuestion`.
final class ChoiceResult {
  /// Google's winning key, the distribution over every key and its
  /// confidence; [predictionSet] is derived from [probabilities].
  ChoiceResult({
    required this.selectedKey,
    required Map<String, double> probabilities,
    required this.confidence,
  }) : probabilities = Map.unmodifiable(probabilities),
       predictionSet = List.unmodifiable(_predictionSet(probabilities));

  /// The option with the highest probability.
  final String selectedKey;

  /// The probability of every option, in the question's order; they sum
  /// to 1.
  final Map<String, double> probabilities;

  /// How certain the choice is, from its margin and entropy, in `[0, 1]`.
  final double confidence;

  /// The most likely options that together cover at least 90% of the
  /// probability, most likely first: one key means the choice is clear,
  /// several mean it is worth disambiguating. Google's Python API computes it
  /// this way; this package does on every platform.
  final List<String> predictionSet;

  @override
  String toString() =>
      'ChoiceResult($selectedKey, probabilities: $probabilities, '
      'confidence: $confidence)';
}

/// The answer to a `ScoreQuestion`.
final class ScoreResult {
  /// Google's expected score, the distribution over the levels, its
  /// confidence and the most likely level.
  ScoreResult({
    required this.expectedScore,
    required List<double> probabilities,
    required this.confidence,
    required this.selectedKey,
  }) : probabilities = List.unmodifiable(probabilities);

  /// The probability-weighted level: 0 for the lowest, up to one less than
  /// the number of levels.
  final double expectedScore;

  /// The probability of each level, lowest first.
  final List<double> probabilities;

  /// How certain the grade is, in `[0, 1]`.
  final double confidence;

  /// Google's key for the most likely level: its index, as text.
  final String selectedKey;

  @override
  String toString() =>
      'ScoreResult($expectedScore, probabilities: $probabilities, '
      'confidence: $confidence, selectedKey: $selectedKey)';
}

/// Google's Python rule: the most likely keys until 90% is covered.
List<String> _predictionSet(Map<String, double> probabilities) {
  final sorted = probabilities.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final keys = <String>[];
  var covered = 0.0;
  for (final entry in sorted) {
    keys.add(entry.key);
    covered += entry.value;
    if (covered >= 0.9) break;
  }
  return keys;
}

/// Google's three decision questions, checked the same way on every
/// platform before they reach Google's runtime.
library;

/// A yes-or-no condition to check against a text: "The customer wants a
/// refund."
final class BooleanQuestion {
  /// [threshold] is the probability at which the answer becomes true;
  /// [temperature] overrides the model's calibrated softmax temperature
  /// when set; [normalizePrior] subtracts the model's empty-context prior
  /// to remove label bias.
  BooleanQuestion(
    this.condition, {
    this.threshold = 0.5,
    this.temperature,
    this.normalizePrior = false,
  }) {
    _checkText(condition, 'condition');
    if (!(threshold >= 0 && threshold <= 1)) {
      throw ArgumentError.value(threshold, 'threshold', 'Must be in [0, 1].');
    }
    _checkTemperature(temperature);
  }

  /// The natural-language condition.
  final String condition;

  /// The answer is true when the probability is at least this.
  final double threshold;

  /// Softmax temperature; null uses the model's calibrated one.
  final double? temperature;

  /// Whether to subtract the empty-context prior. Google's browser runtime
  /// ignores it (upstream-issues.md UP-056).
  final bool normalizePrior;

  /// The question as Google's JavaScript API names it.
  Map<String, Object?> toJson() => {
    'condition': condition,
    'threshold': threshold,
    'temperature': temperature,
    'normalizePrior': normalizePrior,
  };
}

/// How Google's engine scores a choice's options.
enum ChoiceScoringMode {
  /// The engine's choice for the model and options.
  auto,

  /// Each option by its first token.
  singleToken,

  /// Each option by all of its tokens.
  fullOption,
}

/// One of several options for a text: "shipping", "billing" or "other".
final class ChoiceQuestion {
  /// [criteria] maps each option's key to a description of when it applies,
  /// in the order results list them. [instructions] is an optional task
  /// prompt for the model.
  ChoiceQuestion(
    Map<String, String> criteria, {
    this.instructions,
    this.temperature,
    this.scoringMode = ChoiceScoringMode.auto,
    this.normalizePrior = false,
  }) : criteria = Map.unmodifiable(criteria) {
    if (criteria.length < 2) {
      throw ArgumentError.value(
        criteria.length,
        'criteria',
        'A choice needs at least two options.',
      );
    }
    for (final MapEntry(:key, :value) in criteria.entries) {
      _checkText(key, 'criteria key');
      _checkText(value, 'criteria description', empty: true);
    }
    if (instructions case final text?) _checkText(text, 'instructions');
    _checkTemperature(temperature);
  }

  /// Each option's key and description, in order.
  final Map<String, String> criteria;

  /// An optional task prompt.
  final String? instructions;

  /// Softmax temperature; null uses the model's calibrated one.
  final double? temperature;

  /// How the options are scored. Google's browser runtime ignores it
  /// (upstream-issues.md UP-056).
  final ChoiceScoringMode scoringMode;

  /// Whether to subtract the empty-context prior. Google's browser runtime
  /// ignores it (upstream-issues.md UP-056).
  final bool normalizePrior;

  /// The question as Google's JavaScript API names it.
  Map<String, Object?> toJson() => {
    'criteria': criteria,
    'instructions': instructions,
    'temperature': temperature,
    'scoringMode': scoringMode.index,
    'normalizePrior': normalizePrior,
  };
}

/// A grade on an ordered rubric, lowest first: "very unhappy" to "very
/// happy".
final class ScoreQuestion {
  /// [rubric] lists the levels from lowest to highest. [instructions] is an
  /// optional task prompt for the model.
  ScoreQuestion(List<String> rubric, {this.instructions, this.temperature})
    : rubric = List.unmodifiable(rubric) {
    if (rubric.length < 2) {
      throw ArgumentError.value(
        rubric.length,
        'rubric',
        'A rubric needs at least two levels.',
      );
    }
    for (final level in rubric) {
      _checkText(level, 'rubric level');
    }
    if (instructions case final text?) _checkText(text, 'instructions');
    _checkTemperature(temperature);
  }

  /// The levels, lowest first.
  final List<String> rubric;

  /// An optional task prompt.
  final String? instructions;

  /// Softmax temperature; null uses the model's calibrated one.
  final double? temperature;

  /// The question as Google's JavaScript API names it.
  Map<String, Object?> toJson() => {
    'rubric': rubric,
    'instructions': instructions,
    'temperature': temperature,
  };
}

/// Google's C API reads NUL-terminated strings, so an embedded NUL would
/// silently truncate on native platforms only.
void _checkText(String text, String name, {bool empty = false}) {
  if (!empty && text.isEmpty) {
    throw ArgumentError.value(text, name, 'Must not be empty.');
  }
  if (text.contains('\u0000')) {
    throw ArgumentError.value(text, name, 'Must not contain NUL.');
  }
}

void _checkTemperature(double? temperature) {
  if (temperature case final value? when !(value > 0)) {
    throw ArgumentError.value(value, 'temperature', 'Must be > 0.');
  }
}

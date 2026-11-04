/// The settings every classifier takes, the checks they get in every family
/// before Google's runtime sees them, and their names in its JavaScript API.
library;

/// The settings every classifier takes: Image Classifier, Object Detector,
/// Text Classifier, Language Detector, Audio Classifier and Gesture
/// Recognizer's heads. Each task's options document them for that task.
abstract interface class ClassifierSettings {
  /// Locale of the display names in the model metadata.
  String? get displayNamesLocale;

  /// Maximum results; negative returns all of them.
  int get maxResults;

  /// Results scoring below this are dropped.
  double get scoreThreshold;

  /// Category names to keep; exclusive with [categoryDenylist].
  List<String> get categoryAllowlist;

  /// Category names to drop; exclusive with [categoryAllowlist].
  List<String> get categoryDenylist;
}

/// Validates [settings] as Google's runtime would.
void checkClassifierSettings(ClassifierSettings settings) {
  final ClassifierSettings(
    :maxResults,
    :scoreThreshold,
    :displayNamesLocale,
    :categoryAllowlist,
    :categoryDenylist,
  ) = settings;
  // MediaPipe treats a negative count as "no limit"; zero would return
  // nothing, which is a mistake rather than a useful configuration.
  if (maxResults == 0 || maxResults < -0x80000000 || maxResults > 0x7fffffff) {
    throw ArgumentError.value(
      maxResults,
      'maxResults',
      'Must be negative for no limit, or a positive count',
    );
  }
  if (!scoreThreshold.isFinite) {
    throw ArgumentError.value(
      scoreThreshold,
      'scoreThreshold',
      'Must be finite',
    );
  }
  if (categoryAllowlist.isNotEmpty && categoryDenylist.isNotEmpty) {
    throw ArgumentError(
      'Supply at most one of categoryAllowlist and categoryDenylist.',
    );
  }
  if (displayNamesLocale case final locale?) {
    checkLabel(locale, 'displayNamesLocale');
  }
  for (final name in [...categoryAllowlist, ...categoryDenylist]) {
    checkLabel(name, 'category');
  }
}

/// [settings] named as in Google's JavaScript API, for the browser adapters.
///
/// The threshold is always sent, as Google's Python and C APIs apply it:
/// left unset, its JavaScript API applies the model's own threshold (the
/// language detector's drops all but the top language), so the same options
/// would answer differently from the native runtime. A count of zero or
/// less is left unset, which Google reads as every category.
Map<String, Object?> classifierSettingsJson(ClassifierSettings settings) => {
  'displayNamesLocale': ?settings.displayNamesLocale,
  if (settings.maxResults > 0) 'maxResults': settings.maxResults,
  'scoreThreshold': settings.scoreThreshold,
  if (settings.categoryAllowlist.isNotEmpty)
    'categoryAllowlist': settings.categoryAllowlist,
  if (settings.categoryDenylist.isNotEmpty)
    'categoryDenylist': settings.categoryDenylist,
};

/// Requires a nonempty metadata label without NUL.
void checkLabel(String value, String name) {
  if (value.isEmpty || value.contains('\u0000')) {
    throw ArgumentError.value(value, name, 'Invalid metadata label');
  }
}

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/classification.g.dart',
    // cppOptions: CppOptions(namespace: 'pigeon_example'),
    // cppHeaderOut: 'windows/runner/classification.g.h',
    // cppSourceOut: 'windows/runner/classification.g.cpp',
    kotlinOut:
        '../mediapipe_task_text_android/android/src/main/kotlin/com/google/mediapipe_task_text/Classification.g.kt',
    // This file is also used by the macOS project.
    // swiftOut: 'ios/Runner/Classification.g.swift',
    // copyrightHeader: 'pigeons/copyright.txt',
  ),
)

/// A classification category.

/// Category is a util class, contains a label, its display name, a float
/// value as score, and the index of the label in the corresponding label file.
/// Typically it's used as the result of classification tasks.
class Category {
  const Category({
    required this.index,
    required this.score,
    required this.displayName,
    required this.categoryName,
  });

  /// The index of the label in the corresponding label file.
  final int? index;

  /// The probability score of this label category.
  final double? score;

  /// The display name of the label, which may be translated for
  /// different locales. For example, a label, "apple", may be translated into
  // Spanish for display purpose, so that the `display_name` is "manzana".
  final String? displayName;

  /// The label of this category object.
  final String? categoryName;
}

/// Represents the list of classification for a given classifier head.
/// Typically used as a result for classification tasks.
class Classifications {
  const Classifications({
    required this.categories,
    required this.headIndex,
    required this.headName,
  });

  /// The array of predicted categories, usually sorted by descending
  /// scores (e.g. from high to low probability).
  final List<Category?> categories;

  /// The index of the classifier head these categories refer to. This
  /// is useful for multi-head models.
  final int headIndex;

  /// The name of the classifier head, which is the corresponding
  /// tensor metadata name.
  final String? headName;
}

/// Data returned from MediaPipe SDK.
class ClassificationResult {
  const ClassificationResult({
    required this.classifications,
    required this.timestampMs,
  });

  /// The classification results for each head of the model.
  final List<Classifications?> classifications;

  /// The optional timestamp (in milliseconds) of the start of the chunk of
  /// data corresponding to these results.
  final double? timestampMs;
}

@HostApi()
abstract class TextClassifier {
  @async
  ClassificationResult classify(String value);
}

# Migration

This repository's first release, 0.1.0 of `mediapipe_core`,
`mediapipe_vision`, `mediapipe_text`, `mediapipe_audio`, `mediapipe_decision`
and `mediapipe_retrieval`, is the first under these names since Google's
0.0.1 previews of May 2024. This guide is for apps on those previews:

- **`mediapipe_text` 0.0.1:** below, and the complete old-to-new table in
  [the text migration guide](packages/mediapipe-task-text/MIGRATION.md).
- **`mediapipe_core` 0.0.1:** apps rarely used it directly; see
  [the core migration guide](packages/mediapipe-core/MIGRATION.md).
- **`mediapipe_genai` 0.0.1:** has no successor here. This repository removed
  the package, which never moved past Google's 2024 runtime.

`mediapipe_vision` and `mediapipe_audio` are new packages with nothing to
migrate from.

## From Google's `mediapipe_text` 0.0.1

Google's 0.0.1 created tasks with constructors and `BaseOptions`:

```dart
final classifier = TextClassifier(
  TextClassifierOptions.fromAssetPath('assets/bert_classifier.tflite'),
);
```

Now creation is asynchronous, and the model can be a pinned official one:

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<String?> topCategory(String text) async {
  final classifier = await TextClassifier.create(
    TextClassifierOptions(model: TextModels.bertClassifier),
  );
  try {
    final result = await classifier.classify(text);
    return result.classifications.first.categories.first.categoryName;
  } finally {
    await classifier.dispose();
  }
}
```

`TextClassifierOptions(modelBytes: ...)` and `modelPath:` accept your own
model. Results keep Google's shape (`classifications`, `categories`,
`categoryName`, `score`), `dispose()` is idempotent, and calling a disposed
task throws `StateError`. The text tasks run on Android, iOS, macOS, Linux,
Windows and the web.

`model:` takes a model bundled with the app: list it under
`hooks.user_defines.mediapipe_text.models`, declare `assets/mediapipe/` under
`flutter: assets:`, and run `dart run mediapipe_core:bundle_models`. To
download it at run time instead, set `ModelStore.allowDownloads = true` before
creating the task.

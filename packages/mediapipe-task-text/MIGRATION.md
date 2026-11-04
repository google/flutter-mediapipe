# Migrating from Google's mediapipe_text 0.0.1

Google published `mediapipe_text` 0.0.1 in May 2024. This package's first
release, 0.1.0, replaces its API. Import only
`package:mediapipe_text/mediapipe_text.dart`; it re-exports what apps need from
`mediapipe_core`, so apps no longer import `mediapipe_core.dart` themselves.

| Google's 0.0.1 | 0.1.0 |
| --- | --- |
| `TextClassifier(options)`, `TextEmbedder(options)`, `LanguageDetector(options)` | `await TextClassifier.create(options)` and so on |
| `TextClassifierOptions(baseOptions: BaseOptions.path(p))`, `.fromAssetPath(p)` | `TextClassifierOptions(modelPath: p)`, likewise for every task, or a pinned official model with `model: TextModels.bertClassifier` |
| `BaseOptions.memory(bytes)`, `.fromAssetBuffer(bytes)` | `modelBytes: bytes` |
| `classifierOptions: ClassifierOptions(maxResults: 3, ...)` | `maxResults: 3, scoreThreshold: ..., displayNamesLocale: ..., categoryAllowlist: ..., categoryDenylist: ...` on the options |
| `embedderOptions: EmbedderOptions(l2Normalize: ..., quantize: ...)` | `l2Normalize: ..., quantize: ...` on `TextEmbedderOptions` |
| `Category` | `MediaPipeCategory` |
| `classifications`, `categories`, `embeddings` and `predictions` as `Iterable`s | Unmodifiable `List`s |
| `Embedding.float(...)`, `Embedding.quantized(...)`, `type`, `isFloat`, `isQuantized`, core's `EmbeddingType.float` and `.quantized` | `Embedding(floatEmbedding: ...)` or `Embedding(quantizedEmbedding: ...)`; test which is non-null. `EmbeddingType` now names EmbeddingGemma's task types, as Google's does. |
| `await embedder.cosineSimilarity(a, b)` | `TextEmbedder.cosineSimilarity(a, b)` (static, synchronous) |
| `result.dispose()` | Removed; results are plain values |
| `task.dispose()` | `await task.dispose()`, idempotent; calling a disposed task throws `StateError` |

Behavior to know:

- Invalid classifier settings (`maxResults: 0`, or both an allowlist and a
  denylist) throw `ArgumentError` in Dart on every platform, before Google's
  runtime sees them.
- `create` refuses a delegate the capability query rules out with
  `RuntimeUnavailableException`; the classic tasks run on CPU only.
- Runtime failures are `MediaPipeException`s: `RuntimeUnavailableException`
  when the platform or build settings cannot run the task (its `fix` says
  what to change), `TaskException` when Google's runtime fails.

New since 0.0.1: the tasks run on Android, iOS, macOS, Linux, Windows and the
web; EmbeddingGemma, the Proofreader and the Summarizer; per-task capability
queries; and pinned official models. See [CHANGELOG.md](CHANGELOG.md).

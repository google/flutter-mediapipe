# Migrating from Google's mediapipe_core 0.0.1

Google published `mediapipe_core` 0.0.1 in May 2024 as the shared containers
and FFI plumbing of its `mediapipe_text` 0.0.1. This package's first release,
0.1.0, replaces it. Apps now get core through a family's library
(`mediapipe_vision.dart`, `mediapipe_text.dart` or `mediapipe_audio.dart`),
which re-exports `mediapipe_core.dart`; plugins and family packages use
`platform_interface.dart`.

| Google's 0.0.1 | 0.1.0 |
| --- | --- |
| `BaseOptions.path(p)`, `BaseOptions.memory(bytes)` | `modelPath: p` or `modelBytes: bytes` on the task's options (core's `TaskOptions`), or a pinned official model with `model:` |
| `ClassifierOptions(...)`, `EmbedderOptions(...)` | Their settings sit directly on the classifier's or embedder's options |
| `Category` | `MediaPipeCategory` |
| `Classifications`, `Embedding` | `Classifications` and `Embedding`, plain values without `dispose()` |
| `EmbeddingType.float` and `.quantized`, `isFloat`, `isQuantized` | Test whether `floatEmbedding` or `quantizedEmbedding` is non-null |
| `TaskExecutor`, `TaskResult`, the FFI helpers, `io.dart` and `interface.dart` | Not public |

Google's `mediapipe_text` 0.0.1 users: see
[the text migration guide](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-task-text/MIGRATION.md).

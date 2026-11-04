## 0.1.0

The first release of this rewrite, replacing Google's
`mediapipe_text` 0.0.1 (May 2024) with a new API;
[MIGRATION.md](MIGRATION.md) maps it.

- Text Classifier, Text Embedder and Language Detector on Android, iOS,
  macOS, Linux, Windows and the web, through Google's official runtimes.
- On 32-bit Android (armeabi-v7a) the Text Classifier, Text Embedder and
  Language Detector run on the CPU; EmbeddingGemma, the Proofreader and the
  Summarizer need 64-bit Android, since their models take more memory than a
  32-bit process holds.
- EmbeddingGemma, as a `TextEmbedder` with `TextModels.embeddingGemma`, on the
  same six platforms, with Google's prompt formatting on every runtime:
  `embed(text, {formatContext})` with `EmbeddingType`, `TextRole` and
  `TextFormatContext`.
- Proofreader and Summarizer on Android, iOS, macOS, Linux and Windows, with
  streamed updates (`proofreadStream`, `summarizeStream`). Browsers have
  neither task (upstream-issues.md UP-034), which the capability queries
  report.
- Every task is one class with the same API on every platform, created with
  `await Xxx.create(options)` and released with an idempotent `dispose()`.
  `mediapipe_text.dart` is the only app library.
- Options are flat on core's `TaskOptions` (`model`, `modelPath`,
  `modelBytes`, `delegate`) with Google's settings. Results are plain values
  on core's `Classifications`, `Embedding` and `MediaPipeCategory`, and
  `TextEmbedder.cosineSimilarity` is static.
- Per-task capability queries (`queryTextClassifierCapabilities()` and the
  others) report the supported delegates and why any other is unavailable.
  Invalid classifier settings fail in Dart on every platform, and `create`
  refuses the GPU, which no text task runs on.
- `TextModels.byName` names every pinned model for
  `hooks.user_defines.mediapipe_text.models`, which
  `dart run mediapipe_core:bundle_models` bundles into the app. `model:` uses
  the bundled copy and downloads at run time only when
  `ModelStore.allowDownloads` is true; app-supplied paths and bytes work too.

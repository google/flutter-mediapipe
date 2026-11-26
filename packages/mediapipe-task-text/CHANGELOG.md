## 0.5.0

- Upgrade every mediapipe package to 0.5.0 together, so this package now
  requires `mediapipe_core` ^0.5.0, which pins Google's Windows arm64
  libraries. MediaPipe stays at 1.2.3.
- Adds Windows arm64: every text task runs there on the CPU, as on Windows
  x64.
- CI runs every text task on GitHub's `windows-11-arm` runners.
- Every text model now downloads from Google's LiteRT community on Hugging
  Face (`huggingface.co/litert-community`), each pinned to a fixed
  revision, instead of Google's `storage.googleapis.com/mediapipe-models`
  bucket. The files are byte-identical, so their SHA-256 pins are
  unchanged.

## 0.4.1

- Upgrade every mediapipe package to 0.4.1 together, so this package now
  requires `mediapipe_core` ^0.4.1. MediaPipe stays at 1.2.3.
- No change to the text tasks, which run on the CPU on Linux arm64 as on
  Linux x64.

## 0.4.0

- Upgrade every mediapipe package to 0.4.0 together, so this package now
  requires `mediapipe_core` ^0.4.0, which pins Google's Linux arm64
  libraries. MediaPipe stays at 1.2.3.
- Adds Linux arm64 (aarch64): every text task runs there on the CPU, as
  it does on Linux x64.
- Linux arm64 needs glibc 2.27 or later (Raspberry Pi OS Bullseye,
  Ubuntu 18.04 and later) and, even on the CPU, EGL and OpenGL ES:
  `sudo apt-get install libegl1 libgles2`, which Raspberry Pi OS Lite
  lacks. Google's library uses Arm's LSE atomic and RCPC load
  instructions, so it needs a Raspberry Pi 5 (Cortex-A76, ARMv8.2) or
  newer: on a Pi 4 or older (Cortex-A72 or earlier) it stops with an
  illegal instruction.
- CI runs every text task on GitHub's `ubuntu-24.04-arm` runners.
- The package is now licensed under Apache 2.0, like the rest of the
  repository, in place of BSD-3-Clause. Releases up to 0.3.0 keep
  BSD-3-Clause.

## 0.3.0

- Upgrade every mediapipe package to 0.3.0 together. MediaPipe 1.2.3
  changes the layout of the native option structs, so this package now
  requires `mediapipe_core` ^0.3.0.
- Runs Google's MediaPipe 1.2.3 instead of 1.2.2, with new SHA-256 pins
  for its native libraries.
- Accepts Flutter 3.44 and newer, down from 3.47. The package accepts the
  dependency versions Flutter 3.44 resolves, from `hooks` 2.0.0,
  `code_assets` 1.1.0, `native_toolchain_c` 0.19.0 and, for development,
  `ffigen` 21.0.0. iOS and macOS builds with Xcode 27 need Flutter 3.47 or
  later.
- CI tests the package on Flutter 3.50.0, the latest stable release,
  instead of 3.47.9.

## 0.2.1

- The README has a sample that queries every text task's capabilities (the
  Text Embedder's query takes a model), a question answering sample with
  query and document roles and a title, and a key points summary.
- Removes a repeated `@immutable` annotation from `LanguagePrediction`,
  `ProofreadingCorrection`, `TextSummarizerResult` and
  `TextSummarizerUpdate`.

## 0.2.0

- Google's MediaPipe 1.2.2 native release (build of November 2, 2026)
  replaces 1.2.0 on Android, iOS, macOS, Linux and Windows, and
  `@mediapipe/tasks-*` 1.2.2 replaces 1.2.0-rc.20261018 in browsers.
- Google's 1.2.2 Language Detector returns only languages above about 0.3,
  where 1.1.0 returned all 111, whatever `scoreThreshold` says.
  The tests compare with Google's 1.2.2 wheel.

## 0.1.4

- Error messages and the README no longer refer to removed notes.

## 0.1.3

- The README has an installation section using `flutter pub add`.
- With `mediapipe_core` 0.1.3, downloads of models and native libraries wait out
  short network failures.

## 0.1.2

Release 0.1.2.

## 0.1.1

Adds Google's `NOTICE` at the package root.

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
  neither task, which the capability queries report.
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

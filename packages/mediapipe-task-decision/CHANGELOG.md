## 0.5.0

- Upgrade every mediapipe package to 0.5.0 together, so this package now
  requires `mediapipe_core` ^0.5.0, which pins Google's Windows arm64
  libraries. MediaPipe stays at 1.2.3.
- Adds Windows arm64: Decision Maker runs there on the CPU, as on Windows
  x64.
- CI runs Decision Maker on GitHub's `windows-11-arm` runners.
- Laya and GLiNER2.5-Decide now download from Google's LiteRT community on
  Hugging Face (`huggingface.co/litert-community`), each pinned to a fixed
  revision, instead of Google's `storage.googleapis.com/mediapipe-models`
  bucket. The files are byte-identical, so their SHA-256 pins are
  unchanged.

## 0.4.1

- Upgrade every mediapipe package to 0.4.1 together, so this package now
  requires `mediapipe_core` ^0.4.1. MediaPipe stays at 1.2.3.
- No change to Decision Maker. On Linux arm64 a GPU request fails with a
  reason that names the task rather than every task, since four vision
  tasks now run on the GPU there.

## 0.4.0

- Upgrade every mediapipe package to 0.4.0 together, so this package now
  requires `mediapipe_core` ^0.4.0, which pins Google's Linux arm64
  libraries. MediaPipe stays at 1.2.3.
- Adds Linux arm64 (aarch64): Decision Maker runs there on the CPU.
- Linux arm64 needs glibc 2.27 or later (Raspberry Pi OS Bullseye,
  Ubuntu 18.04 and later) and, even on the CPU, EGL and OpenGL ES:
  `sudo apt-get install libegl1 libgles2`, which Raspberry Pi OS Lite
  lacks. Google's library uses Arm's LSE atomic and RCPC load
  instructions, so it needs a Raspberry Pi 5 (Cortex-A76, ARMv8.2) or
  newer: on a Pi 4 or older (Cortex-A72 or earlier) it stops with an
  illegal instruction.
- CI runs Decision Maker on GitHub's `ubuntu-24.04-arm` runners.
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
  dependency versions Flutter 3.44 resolves, from `hooks` 2.0.0 and
  `code_assets` 1.1.0. iOS and macOS builds with Xcode 27 need Flutter
  3.47 or later.
- CI tests the package on Flutter 3.50.0, the latest stable release,
  instead of 3.47.9.

## 0.2.1

- The README has a Batches section with a sample for
  `evaluateBooleanBatch`, `evaluateChoiceBatch` and `evaluateScoreBatch`.
- `evaluateBooleanBatch`'s doc comment says that Google's engine reads
  `sharedPrefix` before each text, joined with a newline, so the texts leave
  it out.
- The README names MediaPipe 1.2.2 as the native runtime.

## 0.2.0

- Google's MediaPipe 1.2.2 native release (build of November 2, 2026)
  replaces 1.2.0 on Android, iOS, macOS, Linux and Windows, and
  `@mediapipe/tasks-*` 1.2.2 replaces 1.2.0-rc.20261018 in browsers.

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

The first release.

- Decision Maker on Android, iOS, macOS, Linux, Windows and the web, through
  Google's official MediaPipe runtimes: its per-family 1.2.0 decision C
  library natively and `@mediapipe/tasks-decision` in browsers.
- Decision Maker needs 64-bit Android: 32-bit (armeabi-v7a) cannot hold its
  models, and `queryDecisionMakerCapabilities` says so.
- `evaluateBoolean`, `evaluateChoice` and `evaluateScore` with Google's
  `BooleanQuestion`, `ChoiceQuestion` and `ScoreQuestion`, plus their batch
  forms, with the same results on every platform.
- `DecisionModels` pins Google's Laya, GLiNER2.5-Decide and EmbeddingGemma 2
  models; `queryDecisionMakerCapabilities(model)` says where a model runs,
  since Google's browser runtime embeds every text as zeros with either
  EmbeddingGemma 2 model in WebKit and aborts with GLiNER2.5-Decide in every
  browser.
- `maxNumTokens` defaults to 0, the model's own token budget, rather than
  the 4096 of Google's Python API: Google's engine reserves memory for the
  whole budget, 6.7 GB with EmbeddingGemma 2 at 4096, beyond what iOS gives
  an iPhone app.
- In browsers Google's runtime ignores `normalizePrior` and `scoringMode`,
  as the questions' documentation says.

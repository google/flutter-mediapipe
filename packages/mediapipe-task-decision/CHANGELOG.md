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

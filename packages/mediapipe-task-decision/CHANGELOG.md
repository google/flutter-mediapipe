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
  since Google's browser runtime embeds every text as zeros with either EmbeddingGemma 2 model in WebKit (UP-054) and
  aborts with GLiNER2.5-Decide in every browser (UP-055).
- `maxNumTokens` defaults to 0, the model's own token budget, rather than
  the 4096 of Google's Python API: Google's engine reserves memory for the
  whole budget, 6.7 GB with EmbeddingGemma 2 at 4096, beyond what iOS gives
  an iPhone app (UP-060).
- In browsers Google's runtime ignores `normalizePrior` and `scoringMode`
  (UP-056), as the questions' documentation says.

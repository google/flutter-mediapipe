## 0.1.0

The first release of this rewrite, replacing Google's
`mediapipe_core` 0.0.1 (May 2024), which held only the shared containers of
Google's text package; [MIGRATION.md](MIGRATION.md) maps that API.

- The shared layer of every task family. `mediapipe_core.dart` is the one
  library apps see, through each family's library, which re-exports it;
  `platform_interface.dart` is for family packages and plugins.
- 32-bit Android (armeabi-v7a), whose libraries Google builds for API 28 too:
  `tasksRuntimeTargets` includes it, for the vision, classic text and audio
  tasks on the CPU; `largeModelRuntimeTargets` leaves it out for the tasks
  whose models a 32-bit process cannot hold, which refuse it with
  `largeModelNeeds64Bit`.
- Downloads, verifies and prepares Google's MediaPipe 1.2.0 C library for
  each family (`bundleFamilyRuntime`), which the vision, text, audio,
  retrieval and decision hooks bundle on Android 9+, iOS, macOS arm64, Linux
  x64 and Windows x64, so an app ships only the families it uses. Each
  library is read from Google's nightly archive with HTTP range requests,
  then from a mirror.
- `downloadVerified` reads a member of a zip archive (a `.zip` URL with the
  member as its fragment), retries a request three times on a connection
  error, a timeout or HTTP 408, 429, 500, 502, 503 or 504, honoring
  `Retry-After`, and resumes a dropped download.
- Shared types: `TaskOptions` (the base of every options class, with `model`,
  `modelPath`, `modelBytes` and `delegate`), one `Delegate`,
  `TaskCapabilities`, and the value types `MediaPipeCategory`,
  `Classifications`, `Embedding`, `Detection`, `BoundingBox`,
  `NormalizedKeypoint`, `NormalizedLandmark`, `Landmark`, `Matrix`,
  `ConfidenceMask` and `CategoryMask`.
- `TaskPlatform.browserEngine` (`BrowserEngine.webkit`, `blink` or `gecko`,
  read from the user agent in browsers), for a family whose browser runtime
  fails in one engine.
- Shared errors: `MediaPipeException`, with `RuntimeUnavailableException`
  (whose `fix` says what to change), `ModelDownloadException` and
  `TaskException`. `checkClassifierSettings` and `requireDelegate` give every
  family the same option checks and delegate refusal. Every classifier's
  options implement `ClassifierSettings`, which `classifierSettingsJson`
  names as Google's JavaScript API does, and `decodeClassifications`,
  `decodeEmbedding` and `decodeCategory` read the results the browser
  adapters deliver.
- Models are bundled with the app at build time.
  `dart run mediapipe_core:bundle_models` downloads the models an app lists
  under `hooks.user_defines.<family>.models`, verifies each against its pin,
  writes them into `assets/mediapipe/` and removes unlisted ones; `--check`
  verifies that folder in CI. A task's `model:` uses the store's cache, then
  the app's bundled copy, and downloads only when `ModelStore.allowDownloads`
  is true; otherwise task creation throws a `RuntimeUnavailableException`
  whose `fix` names the pubspec entry to add.
- `ModelStore`: verified models cached and shared across isolates and
  processes, in Cache Storage in browsers. `get` and `find` return a
  `ModelSource` (`path` on native platforms, `bytes` in browsers), and `find`
  never uses the network.
- Verified runtime downloads with mirror fallback and offline or internal
  sources (`hooks.user_defines.mediapipe_core.asset_source`).
- `MediaPipeWebRuntime`: one setting for where browsers load Google's
  runtimes, every file checked against its pinned SHA-384, and
  `dart run mediapipe_core:web_runtime` to self-host them.

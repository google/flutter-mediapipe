## 0.2.0

- Google's MediaPipe 1.2.2 native release (build of November 2, 2026)
  replaces 1.2.0 on Android, iOS, macOS, Linux and Windows, and
  `@mediapipe/tasks-*` 1.2.2 replaces 1.2.0-rc.20261018 in browsers.
- Sends Google's renumbered `MpDelegate` values (0 is now the default, 1 the
  CPU, 2 the GPU), which 1.2.1 changed in the C API.
- `pin_nightly.py --release X.Y.Z` pins Google's release builds as well as
  nightlies.
- `fillBaseOptions` gives Google's libraries the app's ID and version on
  Android and iOS, as Google's native SDKs do: the package name and
  `versionCode` on Android, the bundle ID and `CFBundleShortVersionString` on
  iOS. Every task accepts them, but with 1.2.2 only eight tasks' usage uploads
  carry them; `doc/privacy_and_licenses.md` names them. Core now depends on
  `jni` and `jni_flutter`, which `path_provider_android` already brings into
  Android apps.
- On Android each family runs its Google library's `JNI_OnLoad` once, before
  its first task, so usage uploads leave Android apps with 1.2.2 as on other
  platforms; Flutter's `dlopen` of the library does not run it.
- Removes `familyRuntimeBaseUrl` and the native libraries' unused mirror URL:
  Google's archive is now their only source.

## 0.1.4

- The README is now the repository's README, word for word, with absolute links
  so it works on GitHub and on pub.dev. Its reference sections (shared types,
  verified downloads and offline builds, bundled and on-demand models, the web
  runtime) moved to [the core guide](https://github.com/google/flutter-mediapipe/blob/main/doc/mediapipe_core.md).
- The README and code comments no longer refer to removed notes.

## 0.1.3

- Downloads of models and native libraries wait out short network failures. At
  the last URL, a failed DNS lookup or a lost connection is retried for 75
  seconds from the first failure, rather than giving up after three attempts
  within seconds. Earlier URLs keep three attempts, so a blocked primary still
  reaches its mirror quickly, and a digest mismatch still moves to the next URL
  at once. With no network at all, the error now appears after about 75 seconds.
- The README says this package comes with every family, and to add it from
  pub.dev only if your own code imports `package:mediapipe_core`.

## 0.1.2

Release 0.1.2.

## 0.1.1

Adds Google's `NOTICE` at the package root.

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

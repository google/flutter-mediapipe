# Per-family runtimes

Status on 2026-10-19: every family, on Android, iOS, macOS, Linux and
Windows, pins Google's MediaPipe 1.2.0 nightly build of October 18, 2026
(see [Google's builds](#googles-builds)), which Google publishes at
`https://storage.googleapis.com/mediapipe-assets/prebuilts/mediapipe_tasks_c/20261018/mediapipe_tasks_c_20261018.zip`.
The hooks read each pinned file from that archive with HTTP range requests,
falling back to the mirror pre-release `per-family-v1.2.0-nightly.20261018` on
`hugocornellier/mediapipe_flutter_native` (not posted yet), beside the
earlier builds in `per-family-v1.1.1-dev.20261009` and
`per-family-v1.1.0-dev.20261005`, and CI and Firebase Test Lab run them (see [Validated](#validated) and
[Before the release](#before-the-release)). Paths are from the repository root.

## What changed

Each task family bundles Google's MediaPipe C library for that family, so an
app ships only the families it depends on, with no setting:

- **Hooks.** `bundleFamilyRuntime` in
  `packages/mediapipe-core/lib/src/native_assets/family_runtimes.dart` pins
  Google's files by SHA-256 and size, fetches them, and bundles one under
  `package:mediapipe_<family>/mediapipe.dylib`. The vision, text and audio
  hooks call it; core's hook only forwards `asset_source`.
- **Bindings.** Every family binds its own asset. Vision's face tasks bind
  the vision library like every other task, so the face asset aliases and the
  macOS source-built face libraries are gone.
- **macOS.** The hook bundles Google's dylib as is: since the October 9 build
  it leaves room for the install name Dart and Flutter write. The earlier
  builds did not
  ([UP-042](../../../upstream-issues.md#up-042-per-family-macos-and-simulator-libraries-have-no-header-room-for-a-rename)),
  so the hook used to rename the system frameworks and sign a copy again.
  `tasks_runtime` (the 95 MB opt-in) is gone: vision is 26.3 MB.
- **iOS.** The hook extracts the arm64 binary from Google's framework zip for
  a device or the Simulator (one zip each since October 9; one XCFramework
  before) and keeps Google's file name. Core's Objective-C++ adapter
  over the iOS SDK (`native/ios`, about 2,400 lines) is gone, with the
  vision package's BGRA pixel pools and its iOS-only Interactive Segmenter:
  iOS uses the same C API path as macOS. The `official_ios_sdk` setting is
  gone with it.
- **Linux and Windows.** Google's per-family libraries replace the wheel
  libraries. Not run yet.
- **Android.** Each family's hook bundles Google's `.so` for the app's ABIs
  (arm64-v8a, armeabi-v7a and x86_64; armeabi-v7a serves the vision, classic
  text and audio tasks on the CPU, and the large models stay on 64-bit), and
  every task calls the C API through FFI, as on iOS and the desktop. The Java
  plugins, core's `TaskHost` library, Google's AARs and their Gradle setup are
  gone, with the `official_android_sdk` setting; the vision plugin only names
  the GPU. The libraries need Android 9: a `minSdk` below 28 fails the build
  with the fix. Model paths reach the C API absolute (`nativeModelPath`),
  since Google's Android resolver reads a relative path as an APK asset.
- **Emulator GPU.** An Android emulator renders OpenGL ES in software
  (SwiftShader), where Google's GPU inference fails, so the vision
  capabilities offer it the CPU only; phones keep the GPU.
- **References.** Every checked-in reference comes from Google's 1.1.0
  release candidate wheel (`mediapipe-nightly` 1.1.0rc20260925), pinned in
  `packages/mediapipe-core/lib/src/native_assets/reference_wheels.dart`,
  which the Dart tests and `tool/official_wheels.py` share. Google has since
  published the final 1.1.0 wheel (October 6) and a 1.1.1 nightly (October
  13); the pin moves, and every fixture is regenerated, once Google says
  whether 1.1.1's Metal output is intended
  ([UP-057](../../../upstream-issues.md#up-057-the-111-macos-library-gives-different-metal-results-from-googles-110-wheel)).
- **Text ABI.** The Proofreader and Summarizer options gained a trailing
  `int min_log_severity` in 1.1.0; the Dart structs have it, set to Google's
  default of 4.

## Local builds

`familyRuntimeArchiveUrl` names Google's archive, and each `FamilyRuntime`
names its file's path in it. `downloadVerified` reads a zip member with HTTP
range requests: the archive's last 64 KiB for the central directory, then the
member's local header and its compressed bytes, which it inflates, so a hook
downloads one library and not the 483 MB archive. Each request gets three
attempts on a connection error, a timeout or HTTP 408, 429, 500, 502, 503 or
504, with a random backoff of up to 1 s × 2^attempt (at most 30 s) or the
host's `Retry-After`, and a dropped download resumes from its last byte.
Another status, a host that ignores ranges or a digest mismatch moves to the
mirror at once.

`familyRuntimeBaseUrl` points at the mirror pre-release. Google gives several
targets' libraries the same file name (four different
`libmediapipe_tasks_vision.so`), so each mirror asset is named
`<sha256>-<Google's file name>`; the hook checks its SHA-256 and size and
saves it under Google's name. `hooks.user_defines.mediapipe_core.asset_source`
replaces both hosts with a directory holding each file under its SHA-256,
for offline builds. That setting covers every pinned download, so the
directory must also hold the models an app bundles. The gallery builder takes
`--asset-source`.

Copies of Google's files keep Firefox's `com.apple.quarantine` flag, and macOS
then refuses to load them; remove it from the copies (`xattr -d`), never from
the originals.

## Validated

### The October 9 build (1.1.1)

Checked on 2026-10-12 against the same references (the 1.1.0 release
candidate wheel), downloading the libraries from the release:

- **macOS arm64** (M4 Max, macOS 27): core 57, text 96 plus the 35 modern
  text checks, audio 45, Decision Maker 22 (1 skipped), Retrieval 29 and
  every vision task on the CPU pass, as do the text tasks beside the face
  tasks in a debug and a release app. Every CPU output matches the wheel
  exactly, in the package suites and in `tool/test_macos_references.py`.
- **Metal, withdrawn.** Google's 1.1.1 Metal output differs from the
  wheel's for every vision task, on the M4 Max (67 checks of
  `tool/test_macos_references.py`) and on GitHub's runners (68), where the
  October 5 build matched it exactly; the release candidate and the final
  1.1.0 wheel give identical GPU output. Google's first 1.1.1 wheel
  (`mediapipe-nightly` 1.1.1rc20261013, October 13) gives the October 9
  build's output exactly in the 36 Image Classifier and Image Embedder cases
  compared, on Metal and on the CPU, so the change is in 1.1.1 itself. The
  vision package offers the CPU only on macOS until Google says whether the
  new output is intended
  ([UP-057](../../../upstream-issues.md#up-057-the-111-macos-library-gives-different-metal-results-from-googles-110-wheel)).
- **Android arm64 emulator** (API 31, CPU): the gallery's `sdk_all_test`
  (32 checks) and its still image test pass. Its logcat still shows the
  usage-logging client's `Failed to get JNIEnv` error.
- **Android phones** (Firebase Test Lab, GPU required): the Pixel 8a, the
  Galaxy S24 and the Galaxy A12 pass all 38 checks; a first Pixel 8a run
  missed one Image Embedder self-consistency check by 0.000001, and its rerun
  passed. Each phone's logcat shows the `Failed to get JNIEnv` error.
- **iOS Simulator** (arm64, CI): every suite passes.
- **CI** (branches `chore/google-1-1-1-libraries` and `chore/oct12-combined`):
  Linux x64 and Windows x64 on the CPU, Linux's GPU (Mesa) against Google's
  GPU wheel, the x86_64 Android emulator, Decision Maker and Retrieval on
  every platform (WebKit on `macos-26` included), the macOS text and modern
  task jobs, and the bundled models pass.
- **iPhone 15 Pro** (GPU required): every iOS suite passes, in a debug and a
  release build of the gallery (see [Before the release](#before-the-release)).

### The October 5 and 8 builds (1.1.0)

On macOS arm64 (M4 Max, macOS 27), against the 1.1.0 references, as
`dart test` counts them:

| Suite | Result |
| --- | --- |
| `mediapipe_core` `dart test` | 55 pass |
| `mediapipe_text` `dart test` | 61 pass |
| `mediapipe_audio` `dart test` | 45 pass |
| `mediapipe_vision` `dart test`, `--tags isolated` | 169 (107 skipped, as before) and 1 pass |
| `mediapipe_text` `--tags modern-text` (EmbeddingGemma, Proofreader, Summarizer; then in `example_embedding`) | 35 pass |
| Gallery: Face Landmarker still image, every vision task's still image, the journey through every page on CPU and Metal | 3 suites pass |

On the arm64 iOS Simulator (iOS 26.4, CPU, as CI runs it), all 12 gallery
suites from `.github/workflows/ios.yaml` pass without core's adapter: every
vision task against Google's references (rotation, padded rows and masks
included), text and audio (the audio stream too), the runtime checks, and the
journey through all 18 pages. Against the 1.1.0 references, EmbeddingGemma's
largest error is 0.0, and Proofreader (9 cases) and Summarizer (10) match
byte for byte.

On an arm64 Android emulator (API 31, CPU), the three gallery suites from
`.github/workflows/android.yaml` pass: `sdk_all_test` (every vision task
against Google's references, rotation and the padded pose mask included, text
and audio with the audio stream, Decision Maker and the retrieval tasks when
the build bundles them, as CI's does since October 13, the live tiles, and the
journey through every page), the still image test, and the modern text suite. EmbeddingGemma's
largest error is 0.0, the Proofreader matches in 9 of 9 cases and the
Summarizer in 8 of 10, within the documented rule
([UP-036](../../../upstream-issues.md#up-036-ios-summarizer-generations-drift-from-googles-wheel-late-in-long-summaries)).
Use an API 31 image on Apple silicon: newer ones advertise the M4's SME, which
the hypervisor refuses, so MediaPipe's CPU code stops with SIGILL.

On CI and Firebase Test Lab (October 7, 2026), downloading the libraries
from the release: Linux x64 and Windows x64 pass every CPU job (every vision
task against Google's wheel on the runner, text, audio, the modern text
tasks, the cameras, bundled models and the gallery); the x86_64 Android
emulator passes its three suites and the arm64 iOS Simulator its 12; macOS
passes every job but the GPU memory test on GitHub's virtual Mac
([UP-032](../../../upstream-issues.md#up-032-macos-gpu-tasks-keep-every-frame-until-they-close)).
On Linux's GPU (Mesa), Hand, Gesture and Pose and Image Segmenter's category
mask match Google's GPU wheel exactly. With the GPU required, the Pixel 8a
(Mali) and Galaxy S24 (Adreno) pass all 38 device tests; the Galaxy A12
(PowerVR) passed 37, the 38th expecting the old plugin's error type.

Against the old 1.0.0 references the split libraries failed 17 Face Detector
GPU checks and one text embedding value. Google's own 1.1.0 wheel gives
bit-identical output, so those were 1.1.0 changes (Face Detector's GPU path
moved to LiteRT), not the packaging. The GPU memory test failed only when other
test files shared its process; it now runs alone (`--tags isolated`).

## Before the release

Done: the hosting above (an official URL from Google would replace it), Linux
and Windows in CI, the Android phones on Test Lab (the Pixel 8a, Galaxy S24
and Galaxy A12, GPU required; Face Detector's, Holistic's and PowerVR's Image
Segmenter GPU are withdrawn there, see
[UP-046](../../../upstream-issues.md#up-046-face-detectors-gpu-needs-a-litert-plugin-the-linux-and-android-libraries-do-not-ship),
[UP-026](../../../upstream-issues.md#up-026-holistic-cannot-open-its-face-blendshapes-model-on-a-desktop-or-iphone-gpu)
and
[UP-023](../../../upstream-issues.md#up-023-android-image-segmenter-gpu-aborts-on-a-powervr-gpu)),
the fresh-app harnesses on one pinned library per family (downloaded as an
app would, or from a local folder through `MEDIAPIPE_ASSET_SOURCE`, which
`tool/mirror_runtime_assets.py --prefill` fills), and the iPhone: every iOS
suite on an iPhone 15 Pro with the GPU required, in a debug and a release
build of the gallery, on `39e3558` (October 13, 2026; the simulator has no GPU
path,
[UP-031](../../../upstream-issues.md#up-031-ios-sdk-gpu-tasks-abort-on-the-ios-simulator)).
Decision Maker and the retrieval tasks have not run on that phone, whose free
storage would not hold their models beside the gallery. The debloat that
preceded 0.1.0 (steps 1 to 9 of its plan) landed in `4b4ab7a`; the plan is in
the history (`git show 4b4ab7a:debloat-plan.md`). Still open:

- **Devices.** Decision Maker and the retrieval tasks on physical phones.
  `.github/workflows/android-face-testlab.yml` now lists
  `universal_embedder,semantic_retriever,decision_maker` with the other 18
  tasks on the Pixel 8a and Galaxy S24, so
  `gallery/integration_test/sdk_all_test.dart` runs their tests there, on the
  CPU, each phone downloading their models on first use; the Galaxy A12 (4 GB,
  29 of its 30 minutes for the other 18) leaves them out. Its first run with
  them is pending.
  An iPhone needs about 1.1 GB free beside the gallery for their models
  (Laya 678 MB, EmbeddingGemma 2 388 MB), downloaded on first use.
- **Ruleset.** Since October 14 the `main` ruleset requires 35 checks by
  name, the Decision, Retrieval and Bundled models checks and the Android
  release suite among them. The phone suite jobs in `android.yaml` and
  `ios.yaml` are now "Every phone suite / official Android SDK on an x64
  emulator" and "... official iOS SDK on an arm64 simulator", and the rule
  requires them by those names. The macOS 14 and Android 9 jobs can join it
  once they have passed on `main`.
- **Publish.** 0.1.0 of the six packages, as `CONTRIBUTING.md` ("Versions
  and the first release") describes. The pubspecs are publishable as checked
  in (no `publish_to: none`, families on `mediapipe_core: ^0.1.0` with a
  checked-in `pubspec_overrides.yaml` for the checkout); `publish_check.py`
  and `test_bundled_models.py` run first, then `mediapipe_core` publishes and
  the five families after it. Dry runs only until then, and never `--force`.
  The `mediapipe_core` and `mediapipe_text` names on pub.dev belong to
  Google's uploaders.
- **Release builds.** On October 14 the gallery with every family built in
  release for iOS (`flutter build ipa`, 670 MB app) and macOS (697 MB). Every
  framework in both is arm64 only, built for iOS 15.0 or macOS 14.0 as its
  Info.plist and the app say, and signed; the macOS app is sandboxed with
  the camera, microphone and network entitlements. Google's iOS libraries
  call required-reason APIs without a privacy manifest, which the gallery
  now declares
  ([UP-062](../../../upstream-issues.md#up-062-the-ios-libraries-call-required-reason-apis-and-ship-no-privacy-manifest)).
  Left: an App Store Connect validation, which needs a bundle ID of the
  account's own instead of `com.example.mediapipeGallery` and an Apple
  Distribution certificate.
- **Notices.** Since October 9, every family ships Google's LICENSE and
  NOTICE, identical across families; the NOTICE opens with Google's
  MediaPipe Tasks privacy notice. The release posts both, and
  `mediapipe_core` carries them (`third_party/`).

## Decision and retrieval

Google's delivery of October 8, 2026 added the `decision` and `retrieval`
families to its per-family libraries, built like the others (LLD on macOS and
the simulator, Apple's ld on iOS devices, Android API 28 with 16 KB pages).

- **Retrieval** (`mediapipe_retrieval`) runs Universal Embedder and Semantic
  Retriever on every target through `familyRuntimes['retrieval']`: Android
  arm64, arm and x86_64; iOS device and simulator; macOS arm64; Linux x64;
  Windows x64; and in browsers on `@mediapipe/tasks-retrieval`. The
  October 9 library exports 60 functions, identical on every platform: the
  two tasks, the Text and Image Embedder and `MpImage` functions they depend
  on, and the shared error, string list and logging functions.
  Google's engine refuses the text-only EmbeddingGemma 2 model for the task
  ([UP-050](../../../upstream-issues.md#up-050-universal-embedder-refuses-the-text-only-embeddinggemma-2-model)),
  so the package pins the text and vision (388 MB) and the full (485 MB)
  models.
- **Decision Maker** (`mediapipe_decision`) runs on the per-family decision
  library through `familyRuntimes['decision']` on Android arm64, arm and
  x86_64, iOS device and simulator, macOS arm64, Linux x64 and Windows x64,
  and on `@mediapipe/tasks-decision` in browsers. The October 9 library
  exports 24 Decision Maker functions (the 13 Google's Python declares, plus
  schema, JSON, context and prewarm evaluation) and the shared helpers; its
  answers match Google's wheel to float precision with Laya and with the
  text and vision EmbeddingGemma 2. Until the October 18 build it failed
  every evaluation with the text-only EmbeddingGemma 2
  ([UP-053](../../../upstream-issues.md#up-053-the-per-family-decision-library-fails-every-evaluation-with-the-text-only-embeddinggemma-2-model)),
  and Windows, which had no decision library, ran the C library from
  Google's 1.1.0 wheel. The October 18 build has a Windows decision library,
  and its macOS library answers the text-only model's cases as Google's
  wheel does. Google's C header for Decision Maker
  (`packages/mediapipe-core/native/include`) matches the package's
  bindings.

## Google's builds

| Build | Libraries |
| --- | --- |
| October 5, 2026, 1.1.0 development | vision, text and audio on every target |
| October 8, 2026, 1.1.0 development | retrieval and decision; Android and iOS rebuilds of vision, text and audio |
| October 9, 2026, 1.1.1 development | every family on every target |
| October 16 to 18, 2026, 1.2.0 nightly (October 18 pinned) | every family on every target, Windows decision included |

`tool/pin_nightly.py --nightly <YYYYMMDD|newest>` pins another nightly:
every library's SHA-256 and size, computed as the hooks check them, Google's
headers, `BUILD_INFO` and notices, and the sentences that name the pinned
build. It stops, writing nothing, if the C API or the MediaPipe version
changed. It does not post the mirror release: a build this project adopts
gets one, keeping the plain archive URL. Runs that only compare a nightly
with the pinned build pass `--generation`, which pins the archive URL to the
generation it hashed (`...zip?generation=<x-goog-generation>`): Google's
bucket keeps that generation when the name is uploaded again, and the hooks
read it with the same range requests, so no mirror is needed.
`tool/test_pin_nightly.py` tests the rewriting offline.

The October 8 phone rebuilds added Google's usage-logging client
(`TasksStatsProtoLogger`, with a Clearcut uploader to
`https://play.googleapis.com/log`), which the desktop and retrieval libraries
already had; the October 5 phone libraries had only a logger that does
nothing, and the October 8 decision libraries had no logger.

The October 9 build (its `BUILD_INFO` is in `packages/mediapipe-core/native`):

- **Header room.** Its macOS dylibs and iOS slices leave 15 to 28 KB, so the
  hook bundles them as is
  ([UP-042](../../../upstream-issues.md#up-042-per-family-macos-and-simulator-libraries-have-no-header-room-for-a-rename)).
- **iOS packaging.** One framework zip for devices and one for the Simulator,
  instead of an XCFramework; the Simulator binary still holds arm64 and
  x86_64.
- **Logging callback.** Every library exports `MpSetLoggingCallback` and
  `MpRemoveLoggingCallback` (`core/mp_logging.h`); see
  [RUNTIME_LOGS.md](RUNTIME_LOGS.md). The six `MpFlatbuffer*` functions are
  gone, though `metadata/flatbuffer_api.h` still declares them.
- **Host environment.** `MpBaseOptions` accepts `MP_HOST_ENVIRONMENT_FLUTTER`
  (5), with the same layout; see [Flutter host
  environment](#flutter-host-environment).
- **Usage logging everywhere.** Every library has the usage-logging client,
  the decision libraries too, which roughly doubles them. On Android the
  client reaches the network through Java, and in an app that loads the
  library through FFI it cannot: Test Lab's logcats of the October 8 build
  show `Failed to get JNIEnv in AndroidNetworkManager::OnAttachedToJvm()`,
  and the October 9 library still has no `JNI_OnLoad` or Java VM setter (see
  [privacy and licenses](../../../doc/privacy_and_licenses.md)).
- **Headers and notices.** Each family ships its C headers, now vendored in
  `packages/mediapipe-core/native/include`, with Google's LICENSE, NOTICE
  and BUILD_INFO.
- **GPU output.** On macOS, Metal output differs from the 1.1.0 wheel's for
  every vision task, so the vision package withdraws the macOS GPU: see
  [Validated](#validated).
- Still no Windows decision library. Linux arm64, Windows arm64 and Android
  x86 libraries come too; no task claims them, so the release does not post
  them.

The October 16 to 18 nightlies (official Kokoro builds, one zip a day at
Google's URL above; the October 18 `BUILD_INFO` is in
`packages/mediapipe-core/native`):

- **Windows decision.** `decision/windows_x86_64/mediapipe_tasks_decision.dll`
  exports the full Decision Maker API, so Windows no longer runs the 1.1.0
  wheel's library.
- **Headers.** Each family's headers are under `<family>/include/`, now with
  the Proofreader, Summarizer and modern Interactive Segmenter;
  `metadata/flatbuffer_api.h` is gone, and the umbrella headers
  (`mediapipe_tasks_<family>.h`) are generated, with no license text.
- **Host environment.** `core/base_options.h` adds
  `MP_HOST_ENVIRONMENT_FLUTTER_WEB` (6), the value for Google's JavaScript
  runtime.
- **Android uploader.** The `Failed to get JNIEnv` message is gone from the
  Android libraries; an upload from an app has not been captured yet.
- **Text-only EmbeddingGemma 2.** The decision library runs it (UP-053
  fixed, checked on macOS arm64).
- iOS framework zips still hold only the binary and `Info.plist` (UP-062).

## Flutter host environment

Google's libraries record each task's host environment and OS in their usage
log, from `MpBaseOptions.host_environment` and `host_system`. Core's
`fillBaseOptions` and the vision package's `setVisionBaseOptions` set
`MP_HOST_ENVIRONMENT_FLUTTER` (5), which the October 9 build added, beside
`host_system` (`mpHostSystem` in
`packages/mediapipe-core/lib/src/host_io.dart`). Before, the environment was
0, and the library then records neither.

- Checked on 2026-10-13 by capturing the uploads on macOS, Linux, Windows
  and the iOS Simulator: each names FLUTTER but records the OS as unknown,
  where the same `host_system` with Google's Python value (3) records it
  ([UP-059](../../../upstream-issues.md#up-059-with-the-flutter-host-environment-the-usage-log-drops-the-os)).
- `host_version` is `mpHostVersion`, written like a browser's user agent
  (`macOS 27.0 / Dart 3.13.4 / Flutter 3.47.5`), as Google asked on
  2026-10-13; the upload carries it as given (checked on macOS). Flutter's
  version comes from the define the Flutter tool sets for `FlutterVersion`.
- `app_id` and `app_version` stay empty: set or not, they appear nowhere in
  the upload.
- In browsers core's worker loader (`assets/verified_runtime.js`) sets
  `globalThis.__HOST_ENVIRONMENT__ = 'FLUTTER_WEB'` before Google's bundle
  loads; Google's JavaScript runtime reads it from 1.2.0-rc.20261017 on, and
  reports WEB without it.

## For Google

Raised on the October 13, 2026 call: Google will add the missing headers to
its next build, and is looking into the Windows decision library, the Metal
change (UP-057), the OS in FLUTTER uploads (UP-059) and the Android
uploader. The October 16 to 18 nightlies brought the headers, the Windows
decision library, the OS in FLUTTER uploads (UP-059, fixed) and an Android
uploader that opens its own connection with no JVM, all observed with the
October 18 build. It agreed to the package layout (core plus one package per
family).

Raised on the October 20, 2026 call, with the October 18 build observed
uploading on every platform and family: no library version in native
uploads, while web sends 1.2.0; the Semantic Retriever's uploads without
host fields (UP-063); the headers' license text (UP-064); and the audio
embeddings' shift and run-to-run variation (UP-058). Google will look into
all four and fix the headers. Not reached, so still to raise: web's empty
host_version (a `__HOST_VERSION__` next to `__HOST_ENVIRONMENT__`);
whether Decision Maker's new logging is intended; closes that wait for the
upload on phones too (UP-025); and the native nightly's cadence, how long
dated builds stay in the bucket, and whether per-family builds will be
part of official releases.

- Raised on the October 15 call: Decision Maker reserves memory for its
  whole token budget, 6.7 GB at Python's default of 4096 tokens with
  EmbeddingGemma 2, and cuts a longer input off without an error; Universal
  Embedder does the same with its input length. Is the reservation intended,
  and can the tasks report the cut-off
  ([UP-060](../../../upstream-issues.md#up-060-decision-maker-and-universal-embedder-reserve-memory-for-their-whole-token-budget))?
- Image Segmenter's GPU mask aborts the app on a Pixel 3 when its size is
  read, and every image accessor converts it first, so no caller can check;
  Google's Java SDK aborted the same way on PowerVR (UP-023), so it is in
  MediaPipe's shared GPU path. The package offers no Image Segmenter GPU on
  Android until it is fixed
  ([UP-061](../../../upstream-issues.md#up-061-image-segmenters-gpu-mask-aborts-the-app-when-it-is-read-on-a-pixel-3)).
- A privacy manifest for each iOS library, or the reasons for the
  required-reason APIs they call (`stat`, `fstat`, `NSUserDefaults`, and
  `statfs` in retrieval), for apps to declare
  ([UP-062](../../../upstream-issues.md#up-062-the-ios-libraries-call-required-reason-apis-and-ship-no-privacy-manifest)).
- Whether 1.1.1's Metal output is intended
  ([UP-057](../../../upstream-issues.md#up-057-the-111-macos-library-gives-different-metal-results-from-googles-110-wheel)).
- Let the Semantic Retriever take base options, or copy its embedder's
  host fields into its own usage uploads; Google is looking into it
  ([UP-063](../../../upstream-issues.md#up-063-semantic-retrievers-usage-uploads-carry-no-os-host-environment-or-host-version)).
- A license comment on the five umbrella headers, and the Apache text
  corrected in `audio_classifier.h`; Google will fix it
  ([UP-064](../../../upstream-issues.md#up-064-the-umbrella-headers-have-no-license-text-and-the-audio-classifier-header-misstates-it)).
- WebKit still embeds every text as zeros with EmbeddingGemma 2 in the
  browser runtime's 1.2.0 nightlies of October 18 and 21 (retested October
  21 with Google's own JavaScript); its Decision Maker now answers "eat" at
  0.9996 or more for every Hungry Fish sentence instead of tying at 0.333
  ([UP-054](../../../upstream-issues.md#up-054-in-webkit-the-browser-runtime-embeds-every-input-as-zeros-with-embeddinggemma-2)).
- The families each define the same Objective-C classes
  ([UP-043](../../../upstream-issues.md#up-043-per-family-libraries-each-define-the-same-objective-c-classes)).
- Apple GPU tasks abort on a three-channel image, as Google's 1.0.0 library
  did
  ([UP-044](../../../upstream-issues.md#up-044-apple-gpu-tasks-abort-on-a-three-channel-image-instead-of-failing)).
- The Windows DLLs export TensorFlow Lite and LiteRT
  ([UP-045](../../../upstream-issues.md#up-045-per-family-windows-libraries-export-tensorflow-lite-and-litert)).
- Ship LiteRT's GPU accelerator plugin with the Linux and Android libraries,
  or link it in as on Apple: Face Detector's GPU cannot run without it
  ([UP-046](../../../upstream-issues.md#up-046-face-detectors-gpu-needs-a-litert-plugin-the-linux-and-android-libraries-do-not-ship)).
- OpenGL ES GPU category masks come back as float32 class values, not uint8
  ([UP-047](../../../upstream-issues.md#up-047-opengl-es-gpu-category-masks-come-back-as-float32)).
- On GitHub's virtual Mac, LiteRT cannot create a Metal residency set and
  Face Detector keeps about twice each frame
  ([UP-032](../../../upstream-issues.md#up-032-macos-gpu-tasks-keep-every-frame-until-they-close)).
- A Python wheel from the same build as the libraries, for the references
  ([UP-036](../../../upstream-issues.md#up-036-ios-summarizer-generations-drift-from-googles-wheel-late-in-long-summaries)).
  Google's first 1.1.1 wheel, `mediapipe-nightly` 1.1.1rc20261013, matches
  the October 9 build's Image Classifier and Image Embedder exactly; its
  Summarizer has not been compared.
- An official URL for releases; the nightlies have one since October 16.

## Sizes

Google's per-family libraries of the October 9 build, in MB (10^6 bytes;
all stripped):

| Platform | Vision | Text | Audio | All three | Retrieval | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| iOS arm64 (device binary) | 19.8 | 20.2 | 9.8 | 49.8 | 13.9 | 12.6 |
| macOS arm64 | 26.3 | 25.0 | 12.6 | 63.9 | 19.0 | 16.5 |
| Linux x64 | 29.4 | 38.2 | 19.8 | 87.4 | 27.5 | 32.1 |
| Windows x64 | 24.1 | 37.4 | 17.0 | 78.5 | 21.8 | none |
| Android arm64-v8a | 13.4 | 14.6 | 8.8 | 36.8 | 12.0 | 15.1 |
| Android x86_64 | 16.6 | 18.0 | 11.4 | 46.0 | 15.0 | 18.5 |

The Android arm64-v8a and x86_64 libraries are aligned for 16 KB pages.

Google's 1.1.0 single library (the `mediapipe-nightly` 1.1.0rc20260925
wheels), for comparison: macOS arm64 102.1, Linux x64 88.8 (both stripped)
and Windows x64 57.8. Per family is smaller in every combination on macOS
and Linux, and larger on Windows when text is combined with vision (61.5) or
with both others (78.5). Google prefers per family everywhere, so the hooks
have no per-platform choice.

Downloading native code at run time is not an option on mobile: iOS loads
only code signed into the app bundle (App Store Review Guideline 2.5.2), and
Google Play forbids executable code from outside Play. The choice stays at
build time.

# Privacy and licenses

## What is downloaded, and from where

Inference runs on the device: images, audio and text you pass to a task are
not sent anywhere by these packages. The packages do download software and
models, each pinned to one SHA-256 (SHA-384 for browser files) and rejected
if the bytes differ.

At build time, the build hooks fetch the native runtime for the target:

| What | Host |
| --- | --- |
| Google's per-family MediaPipe libraries (Android, iOS, macOS, Linux, Windows), read from Google's nightly archive | `storage.googleapis.com` |
| The same files, only when Google's archive fails: a mirror posted unmodified as a pre-release of `hugocornellier/mediapipe_flutter_native` | `github.com`, which redirects to `release-assets.githubusercontent.com` |

At run time:

| What | Host |
| --- | --- |
| Pinned models, only when the app sets `ModelStore.allowDownloads = true` or calls `ModelStore` itself; bundled models are fetched at build time by `dart run mediapipe_core:bundle_models` instead | `storage.googleapis.com`; the EmbeddingGemma 2 models (Decision Maker and Retrieval) from `huggingface.co`, which redirects to its CDN (`*.hf.co`) |
| Google's browser runtime (web only), unless self-hosted | `cdn.jsdelivr.net` |

`hooks.user_defines.mediapipe_core.asset_source`, `ModelStore(source: ...)`
and self-hosting the browser runtime replace these hosts with your own; see
[platform setup](platform_setup.md).

### Google's usage logging

Google's MediaPipe runtimes send usage metrics to Google: the task, its
running mode, latencies and input counts, never the images, audio or text it
processes. On native platforms the packages also name Flutter as the host
environment, with the versions of the OS, Dart and Flutter (for example
`iOS 26.4 / Dart 3.13.4 / Flutter 3.47.5`), which the uploads record. In
browsers they name Flutter Web as the host environment.
Google's NOTICE opens with its MediaPipe Tasks privacy notice, which makes
the app's developer responsible for getting users' informed consent where the
law requires it. The packages cannot turn the logging off.

| Where | What the packages bundle | Usage logging |
| --- | --- | --- |
| macOS, Linux, Windows | Google's per-family 1.2.0 libraries | An uploader to `https://play.googleapis.com/log` in every library. Observed with Google's October 18 build on all three, every family: one request per task close, which Google accepts (HTTP 200). On macOS the User-Agent carries the process name. On Windows a close waits for its upload ([UP-025](../upstream-issues.md#up-025-windows-task-closes-wait-for-googles-usage-logging-upload)) |
| iOS | Google's per-family 1.2.0 libraries | The same uploader. Observed with the October 18 build on the iOS Simulator (every family) and on an iPhone: one request per task close, which Google accepts, with the app's bundle ID and version, the iOS version and the device model in the User-Agent |
| Android | Google's per-family 1.2.0 libraries | The same uploader, which since the 1.2.0 nightlies opens its own connection rather than going through Java. Observed with the October 18 build on an emulator, where Google accepts one request per task close, and on physical phones from Android 9 to 15, 64-bit and 32-bit, where each task close opens one connection to Google of the same size and waits for it, up to about 2.5 s on the oldest phone ([UP-025](../upstream-issues.md#up-025-windows-task-closes-wait-for-googles-usage-logging-upload)) |
| Browsers | Google's JavaScript runtimes | Requests from the page to `https://odml.pa.googleapis.com/v1/log` when a task closes and every 60 seconds while one is open. Observed with the October 18 build in Chromium and WebKit, every family, which Google accepts |

Every family uploads, Decision Maker included: each was observed with the
October 18 build on macOS, Linux, Windows, the iOS Simulator and in browsers,
and on Android phones for the vision, text, audio, Universal Embedder and
Decision Maker closes. One task's uploads are incomplete: the Semantic
Retriever's name no OS, host environment or host version, on every native
platform and under Google's own Python, because its options take none
([UP-063](../upstream-issues.md#up-063-semantic-retrievers-usage-uploads-carry-no-os-host-environment-or-host-version)).

Block those endpoints if your policy requires it: inference is unaffected. A
task's close waits for its upload, so refuse the connection (for example
through the hosts file) rather than drop its packets, which makes each close
wait for the upload to time out (about 4 seconds on iOS).

## App Store privacy manifest

App Store Connect refuses an iOS app whose code calls an API on Apple's
required-reason list without declaring why (ITMS-91053). Google's iOS
libraries call some and carry no privacy manifest, and a Flutter build cannot
add one to them
([UP-062](../upstream-issues.md#up-062-the-ios-libraries-call-required-reason-apis-and-ship-no-privacy-manifest)),
so an app that uses these packages declares them in its own
`ios/Runner/PrivacyInfo.xcprivacy`, added to the Runner target in Xcode:

| Families | Category (`NSPrivacyAccessedAPIType`) | Called through | The gallery's reason |
| --- | --- | --- | --- |
| Every family | `NSPrivacyAccessedAPICategoryFileTimestamp` | `stat`, `fstat` | `C617.1`: files inside the app's container, such as its models |
| Every family | `NSPrivacyAccessedAPICategoryUserDefaults` | `NSUserDefaults` | `CA92.1`: values only the app reads |
| `mediapipe_retrieval` | `NSPrivacyAccessedAPICategoryDiskSpace` | `statfs`, `fstatfs` | `E174.1`: checking for space before writing files |

The reasons are the gallery's reading of what Google's code does, which
Google has not confirmed; the app's developer answers for the ones it
declares. [The gallery's manifest](../gallery/ios/Runner/PrivacyInfo.xcprivacy)
is a starting point. The usage logging above is data the app's App Privacy
answers in App Store Connect must describe.

## Licenses

- This repository's source: [Apache-2.0](../LICENSE), with upstream notices
  retained.
- Google's MediaPipe runtimes: Apache-2.0. `mediapipe_core` carries the
  `LICENSE` and `NOTICE` Google ships with the libraries it pins
  (`third_party/`, identical for every family), which apps redistribute with
  the runtime. The vision package also keeps OpenCV's
  carotene notices (`third_party/OPENCV_CAROTENE_NOTICES`) until Google
  confirms whether its libraries need them.
- Google's MediaPipe task models (the pins in each family's `models.dart`):
  Apache-2.0, per Google's model cards, except the Gemma-based text models.
- EmbeddingGemma, Proofreader and Summarizer are Gemma models, under the
  [Gemma Terms of Use](https://ai.google.dev/gemma/terms) and its
  [Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy).
  An app that ships or downloads them must pass those terms on to its users.

`python3 -B packages/mediapipe-core/tool/mirror_runtime_assets.py` lists every
pinned runtime and model with its license.

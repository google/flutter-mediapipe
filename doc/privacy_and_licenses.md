# Privacy and licenses

## What is downloaded, and from where

Inference runs on the device: images, audio and text you pass to a task are
not sent anywhere by these packages. The packages do download software and
models, each pinned to one SHA-256 (SHA-384 for browser files) and rejected
if the bytes differ.

At build time, the build hooks fetch the native runtime for the target:

| What | Host |
| --- | --- |
| Google's per-family MediaPipe libraries (Android, iOS, macOS, Linux, Windows), read from Google's release archive | `storage.googleapis.com` |

At run time:

| What | Host |
| --- | --- |
| Pinned models, only when the app sets `ModelStore.allowDownloads = true` or calls `ModelStore` itself; bundled models are fetched at build time by `dart run mediapipe_core:bundle_models` instead | `storage.googleapis.com`; the EmbeddingGemma 2 models (Decision Maker and Retrieval) and the speech models (Parakeet, Phonon, Kokoro and PocketTTS) from `huggingface.co`, which redirects to its CDN (`*.hf.co`) |
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

On Android and iOS the packages also give Google's libraries the app's ID and
version, as Google's native SDKs do: the package name and `versionCode` on
Android, the bundle ID and `CFBundleShortVersionString` on iOS. Every task
accepts these fields, but with the pinned 1.2.2 libraries only eight tasks
include them in their uploads: Audio Transcriber, Decision Maker, Interactive
Segmenter, Semantic Retriever, Text Proofreader, Text Summarizer, Text to
Speech and Universal Embedder. The other tasks' uploads leave both fields
empty. On Android the uploads leave the app only because the packages run
each library's `JNI_OnLoad` (see the table below). The packages set neither
on macOS, Linux, Windows or in browsers.

Google's NOTICE opens with its MediaPipe Tasks privacy notice, which makes
the app's developer responsible for getting users' informed consent where the
law requires it. The packages cannot turn the logging off.

| Where | What the packages bundle | Usage logging |
| --- | --- | --- |
| macOS, Linux, Windows | Google's per-family 1.2.2 libraries | An uploader to `https://play.googleapis.com/log` in every library. Observed with Google's October 18 build on all three, every family: one request per task close, which Google accepts (HTTP 200). Captured again with 1.2.2 on macOS only, every task, with the uploads kept from Google. On macOS the User-Agent carries the process name. On Windows a close waits for its upload |
| iOS | Google's per-family 1.2.2 libraries | The same uploader. Observed with the October 18 build on the iOS Simulator (every family) and on an iPhone: one request per task close, which Google accepts, with the app's bundle ID and version, the iOS version and the device model in the User-Agent. Captured again with 1.2.2 on the Simulator only, with the same User-Agent on every upload, whichever task sent it |
| Android | Google's per-family 1.2.2 libraries | The same uploader, which since Google's nightly of October 21 goes through Java and needs the `JavaVM` that each library's `JNI_OnLoad` stores. Flutter loads the library with `dlopen`, which does not run it, so the packages run it themselves, once per library, before the family's first task. Observed with 1.2.2 in a debug build on an API 31 emulator: one request per task close leaves the app, Interactive Segmenter's with the app's ID and version, and none without that call. Observed again with 1.2.2 in a debug build on a Pixel 8a (Android 15): each of eight task closes opened one connection to Google and sent about 1 to 1.3 KB, with no JNI errors in the log. The October 18 build did upload, opening its own connection: on an emulator, where Google accepts one request per task close, and on physical phones from Android 9 to 15, 64-bit and 32-bit, where each task close opens one connection to Google of the same size and waits for it, up to about 2.5 s on the oldest phone |
| Browsers | Google's JavaScript runtimes | Requests from the page to `https://odml.pa.googleapis.com/v1/log` when a task closes and every 60 seconds while one is open. Observed with the October 18 build in Chromium and WebKit, every family, which Google accepts |

With the October 18 build every family uploaded, Decision Maker included:
each was observed on macOS, Linux, Windows, the iOS Simulator and in browsers,
and on Android phones for the vision, text, audio, Universal Embedder and
Decision Maker closes. With that build the Semantic Retriever's uploads named
no OS, host environment or host version; with 1.2.2 they name all three.

Block those endpoints if your policy requires it: inference is unaffected. A
task's close waits for its upload, so refuse the connection (for example
through the hosts file) rather than drop its packets, which makes each close
wait for the upload to time out (about 4 seconds on iOS).

## App Store privacy manifest

App Store Connect refuses an iOS app whose code calls an API on Apple's
required-reason list without declaring why (ITMS-91053). Google's iOS
libraries call some and carry no privacy manifest, and a Flutter build cannot
add one to them, so an app that uses these packages declares them in its own
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
- The gallery's bundled Roboto font (`gallery/fonts/`): the
  [SIL Open Font License 1.1](../gallery/fonts/OFL-Roboto.txt), Copyright 2011
  The Roboto Project Authors. The font files are unmodified.
- Google's MediaPipe runtimes: Apache-2.0. `mediapipe_core` carries the
  `LICENSE` and `NOTICE` Google ships with the libraries it pins
  (`third_party/`, identical for every family), which apps redistribute with
  the runtime, and every package keeps a copy of that `NOTICE` at its root.
  The vision package also keeps OpenCV's carotene notices (`third_party/OPENCV_CAROTENE_NOTICES`) until Google
  confirms whether its libraries need them.
- The task models (the pins in each family's `models.dart`): Apache-2.0, per
  their model cards, except the Gemma-based text models and two speech models
  under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): NVIDIA's
  Parakeet TDT 0.6B v3 (`AudioModels.parakeetTdtV3`) and Kyutai's PocketTTS
  (`AudioModels.pocketTtsEn`). An app that ships or downloads either credits
  its author (NVIDIA or Kyutai), for example in its open source notices, as
  Google's
  [Text to Speech guide](https://developers.google.com/edge/mediapipe/solutions/audio/text_to_speech)
  asks for PocketTTS.
- The Text Embedder's EmbeddingGemma 300M (`TextModels.embeddingGemma`,
  `embedding_gemma.task`), the Proofreader and the Summarizer are Gemma
  models, under the [Gemma Terms of Use](https://ai.google.dev/gemma/terms)
  and its
  [Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy).
  An app that ships or downloads them must pass those terms on to its users.
  The EmbeddingGemma 2 models of Decision Maker and Retrieval are not: their
  model cards say Apache-2.0.

`python3 -B packages/mediapipe-core/tool/mirror_runtime_assets.py` lists every
pinned runtime and model with its license.

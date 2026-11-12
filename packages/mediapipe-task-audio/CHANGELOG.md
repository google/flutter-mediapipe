## 0.3.0

- Upgrade every mediapipe package to 0.3.0 together. MediaPipe 1.2.3
  changes the layout of the native option structs, so this package now
  requires `mediapipe_core` ^0.3.0.
- Runs Google's MediaPipe 1.2.3 instead of 1.2.2, with new SHA-256 pins
  for its native libraries.
- Text to Speech word indices in the browser stay correct UTF-16 indices
  on Google's 1.2.3 web runtime, which changed their unit from UTF-8 bytes
  to UTF-16 indices.
- Accepts Flutter 3.44 and newer, down from 3.47. The package accepts the
  dependency versions Flutter 3.44 resolves, from `hooks` 2.0.0,
  `code_assets` 1.1.0 and `native_toolchain_c` 0.19.0. iOS and macOS
  builds with Xcode 27 need Flutter 3.47 or later.
- CI tests the package on Flutter 3.50.0, the latest stable release,
  instead of 3.47.9.
- The README's Audio Transcriber sample for a clip only transcribes: it no
  longer ends with a `speak()` function, which is Text to Speech code, as
  Google's Audio Transcriber guide shows it. The Speech section keeps its
  own Text to Speech samples.

## 0.2.1

- The README has complete samples for live transcription with interim
  results, `prewarm()`, streamed speech with word timestamps and a stop, and
  choosing a voice for a locale with `listVoices()` and `cancel()`. It also
  describes `modelArchitecture`, `prompt`, `cacheDirectory`,
  `defaultVoiceId`, `speakingRate` and `targetBucket`.
- `synthesizeStream`'s doc comment and the README say that it yields short
  chunks (80 to 320 ms of audio each with Phonon) rather than one per clause.

## 0.2.0

- Audio Transcriber: speech to text on Google's 1.2.2 native library, with
  `AudioModels.parakeetTdtV3` (Parakeet TDT 0.6B v3), whole clips or blocks
  ending in `finishStream()`, optional interim results, and segment
  timestamps.
- Text to Speech: `synthesize` and `synthesizeStream` with
  `AudioModels.phonon` (five US English voices), speaking rate, voice
  and locale per call, and word timestamps.
- Text to Speech `cancel()`, like Google's: a cancelled `synthesize` call
  fails with status 1, a cancelled stream closes cleanly, and cancelling a
  `synthesizeStream` subscription stops Google's stream at once (in
  browsers, between its chunks).
- `TextToSpeechOptions.defaultLocale` is null by default, so Google infers the
  locale from the voice, as its Web, Android and iOS tasks do, and a Kokoro
  voice in another language needs no locale (Google refuses it in `en-US`).
- Text to Speech also speaks US English with Kyutai's PocketTTS
  (`AudioModels.pocketTtsEn`, CC BY 4.0) on the CPU.
- Text to Speech also pins hexgrad's Kokoro 82M (`AudioModels.kokoro`,
  Apache 2.0) in eight languages: the file Google's guide uses with the GPU
  delegate, whose speech may be noisier on the CPU.
- Both run on the CPU on 64-bit Android, iOS, macOS, Linux and Windows, and
  in browsers on `@mediapipe/tasks-audio` 1.2.2, each on a web worker; 32-bit
  Android reports them unavailable.
- Audio Transcriber also offers the GPU delegate where a test saw the GPU do
  the work: macOS, which CI checks on macOS 15, Chromium on a Mac's Apple
  WebGPU adapter, which CI checks on macOS 15, and WebKit on that adapter,
  checked on a developer's Mac. iPhones and iPads are offered Metal too,
  tested on one iPhone 15 Pro (iOS 27): the same transcript as the CPU, about
  1.7x faster per clip, but about 578 MB of GPU memory and about 4.6 s to
  create (0.6 s on the CPU). iPads and older iPhones were not tested. Other
  browsers and other adapters get the CPU, and a reason. Text to Speech offers
  the GPU on macOS 15 and later for Kokoro (`AudioModels.kokoro`).
- On Linux, Text to Speech checks first that the model path is a file and
  throws a `TaskException` (NOT_FOUND, 5) for every path that is not: there
  Google's library ends the process for a missing Phonon or PocketTTS file and
  for a directory with Phonon's file name, and returns 2 for a directory with
  Kokoro's file name.
- `AudioTranscriberOptions.sampleRateHz` of 0 means 16000, as in Google's
  API, and a negative rate throws an `ArgumentError`.
- Google's 1.2.2 native library replaces 1.2.0, and `@mediapipe/tasks-audio`
  1.2.2 replaces 1.2.0-rc.20261018 in browsers.

## 0.1.4

- No changes to this package. It is released with `mediapipe_core` 0.1.4 so that all the packages keep one version.

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

- Audio Classifier on Android, iOS, macOS, Linux, Windows and the web,
  through Google's official runtimes, classifying PCM clips (`AudioData`,
  with a WAV decoder) at any sample rate.
- On 32-bit Android (armeabi-v7a) the Audio Classifier runs on the CPU.
- Audio stream mode on every platform: `AudioClassifierOptions(runningMode:
  AudioRunningMode.audioStream)` creates a task that takes blocks of any
  length with `classifyAsync(block, timestampMilliseconds:)` and delivers one
  result per model window on `results`, stamped with where the window's audio
  starts; `dispose()` classifies the tail. Google's own stream runs it on
  Android, iOS, macOS, Linux and Windows; in browsers, where Google has none,
  the package emulates it on Google's clips mode. The rate, channel and
  timestamp checks run in Dart with one message on every platform. Outside
  browsers at most 64 streams can be open at once.
  `classify` on a stream task, and `classifyAsync` or `results` on a clips
  task, throw `StateError`.
- `AudioClassifierResult` has `classifications` (one `Classifications` per
  model head) and `timestampMilliseconds`. `AudioClassifierOptions` extends
  core's `TaskOptions` with Google's classifier settings and `runningMode`.
- `AudioModels.byName` names YAMNet for
  `hooks.user_defines.mediapipe_audio.models`, which
  `dart run mediapipe_core:bundle_models` bundles into the app. `model:` uses
  the bundled copy and downloads at run time only when
  `ModelStore.allowDownloads` is true; app-supplied paths and bytes work too.

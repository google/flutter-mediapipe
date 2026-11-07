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

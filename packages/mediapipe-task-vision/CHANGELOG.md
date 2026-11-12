## 0.3.0

- Upgrade every mediapipe package to 0.3.0 together. MediaPipe 1.2.3
  changes the layout of the native option structs, so this package now
  requires `mediapipe_core` ^0.3.0.
- Runs Google's MediaPipe 1.2.3 instead of 1.2.2, with new SHA-256 pins
  for its native libraries.
- On Linux, Hand Landmarker, Gesture Recognizer and Pose Landmarker now
  run on the CPU only. Google's 1.2.3 Linux library runs part of their
  graphs on LiteRT, whose GPU plugin (libLiteRtGpuAccelerator.so) it does
  not ship, so their GPU graphs fail to open; 1.2.2 ran them on the GPU.
  Asking for the GPU there fails with a clear reason, as it already does
  for Face Detector.
- On Android, Hand Landmarker, Gesture Recognizer and Pose Landmarker now
  run on the CPU only as well: Google's 1.2.3 Android library needs the
  same missing GPU plugin, so their GPU graphs failed to open on a Pixel
  8a, where 1.2.2 ran all three on the GPU. Asking for the GPU there fails
  with a clear reason, and the gallery opens them on the CPU.
- Accepts Flutter 3.44 and newer, down from 3.47. The package accepts the
  dependency versions Flutter 3.44 resolves, from `hooks` 2.0.0,
  `code_assets` 1.1.0 and, for development, `ffigen` 21.0.0. iOS and macOS
  builds with Xcode 27 need Flutter 3.47 or later.
- CI tests the package on Flutter 3.50.0, the latest stable release,
  instead of 3.47.9.
- The object detection sample app builds on Flutter 3.44.0, 3.47.9 and
  3.50.0: its Android project uses the Android Gradle plugin 9.3.3, Gradle
  9.5.0 and Kotlin 2.4.20, and it takes its Material widgets from
  `material_ui` 1.2.0 or later, since Flutter 3.50 deprecates the SDK's
  copy.

## 0.2.1

- The README's video and live stream samples are complete functions. The live
  stream sample gives a frame that arrives in the same millisecond as the one
  before it the next millisecond, since a repeated timestamp throws.
- The README's GPU sample takes the delegate from the capability query and
  falls back to the CPU when the GPU it was offered is refused, as on Linux
  with only a software renderer.
- The README has a browser sample that draws face landmarks over a playing
  `<video>` with `BrowserOverlay` and `VisionImage.fromBrowserFrame`.
- Two new guides: [video and live stream samples](https://github.com/google/flutter-mediapipe/blob/main/doc/guides/vision/video_and_live_stream.md)
  for each of the ten camera tasks, and
  [options and extra outputs](https://github.com/google/flutter-mediapipe/blob/main/doc/guides/vision/options_and_outputs.md):
  capability queries, regions of interest, RGB input, transformation
  matrices, masks, quantized embeddings and the tuning options.
- The README's link to the object detection sample app points to
  `samples/apps/object_detection`, where the app moved.
- In WebKit browsers, a task whose create fails is created once more in a
  fresh worker with its own copy of the model bytes. On macOS WebKit,
  Google's web runtime sometimes fails to create a sound task, for example
  with "Unable to initialize TagMaps for node"; a model that is really bad
  fails both times. Each retry logs a `MEDIAPIPE_WEBKIT_CREATE_RETRY`
  warning in the console.

## 0.2.0

- Google's MediaPipe 1.2.2 native release (build of November 2, 2026)
  replaces 1.2.0 on Android, iOS, macOS, Linux and Windows, and
  `@mediapipe/tasks-*` 1.2.2 replaces 1.2.0-rc.20261018 in browsers.
- The regenerated bindings carry Google's renumbered delegates.
- Gives Google's library the app's ID and version on Android and iOS, as
  core's `fillBaseOptions` does. Every vision task accepts them, but with 1.2.2 only
  Interactive Segmenter's usage uploads carry them; the other vision tasks
  upload both fields empty.
- The README and the support matrix say that GPU on iPhone was tested on an
  iPhone 15 Pro (iOS 27) with 1.2.2, for the nine tasks with an iOS GPU path.

## 0.1.4

- The README's links to `mediapipe_core`'s reference sections point to
  [the core guide](https://github.com/google/flutter-mediapipe/blob/main/doc/mediapipe_core.md),
  where those sections moved.
- Error messages and the README no longer refer to removed notes.

## 0.1.3

- The README installs the package with `flutter pub add`, drops the steps for
  depending on a clone by path, states the Flutter 3.47 minimum and recommends
  the latest stable release.
- With `mediapipe_core` 0.1.3, downloads of models and native libraries wait out
  short network failures.

## 0.1.2

Release 0.1.2.

## 0.1.1

Adds Google's `NOTICE` at the package root.

## 0.1.0

The first release.

- Face Detector, Face Landmarker, Hand Landmarker, Gesture Recognizer, Pose
  Landmarker, Holistic Landmarker, Object Detector, Image Classifier, Image
  Embedder, Image Segmenter and Interactive Segmenter on Android, iOS, macOS,
  Linux, Windows and the web, through Google's official runtimes. Windows has
  no Interactive Segmenter: Google's Windows runtime takes about 25 seconds
  a stroke.
- On 32-bit Android (armeabi-v7a) every task runs on the CPU; the GPU is not
  offered there yet.
- Image Segmenter offers only the CPU on Android: Google's Android task
  aborts the app when it reads a GPU mask on PowerVR and Adreno 630 GPUs,
  in its C library and its Java SDK alike.
- Every task is one class with the same API on every platform, and
  `mediapipe_vision.dart` is the only app library. Tasks use Google's verbs
  (`detect`, `recognize`, `classify`, `embed` and `segment`, and their
  `ForVideo` forms), and results use core's shared types (`Detection`,
  `BoundingBox`, `MediaPipeCategory`, `NormalizedLandmark` and `Landmark`,
  `Matrix`, `Classifications`, `Embedding`, `ConfidenceMask`). Every
  result extends `VisionResult`, with the input's size and the frame's
  timestamp.
- Image, video and live stream running modes on every platform, the web
  included. In live stream mode every camera-capable task has `detectAsync`
  (`recognizeAsync`, `classifyAsync`, `embedAsync`, `segmentAsync`), a
  `results` stream and `droppedFrames`. Google's flow limiter (one frame in
  flight, the newest one waiting) runs in front of Google's VIDEO graph, so a
  frame that runs gets the result Google's LIVE_STREAM gives it, and a
  dropped frame is never copied to the runtime. `VisionImage.deferred`
  converts a live stream frame only when the task starts it.
- `VisionImage.fromBrowserFrame` and `BrowserOverlay` for browser camera
  frames; both exist on every platform.
- The Interactive Segmenter takes Google's `Stroke` and `BrushMode`, with
  Google's rule that a stroke of any mode has at least one point, and
  returns a `ConfidenceMask`. Image Classifier and Image Embedder take a
  region of interest.
- `queryXxxCapabilities()` reports the supported delegates and why any other
  is unavailable. The same input checks run on every platform, with the
  browser's timestamp limit (9007199254740 ms) everywhere, and errors name
  the task.
- `VisionModels.byName` names every pinned model for
  `hooks.user_defines.mediapipe_vision.models`, which
  `dart run mediapipe_core:bundle_models` bundles into the app. `model:` uses
  the bundled copy and downloads at run time only when
  `ModelStore.allowDownloads` is true; app-supplied paths and bytes work too.
- The `tasks` build setting leaves the face tasks' own macOS libraries out of
  apps that do not use them.
- On macOS every task runs on the CPU for now: Google's library since 1.1.1 gives
  different Metal results from its 1.1.0 wheel, so the GPU stays withdrawn
  until Google says whether the change is intended.
- On macOS, a GPU task reopens its native task after converting 1 GiB of
  frames, since Google's macOS GPU path keeps every frame until the task
  closes. Tasks that reopen hold their model in memory, so the app may delete
  the model file after creating them.

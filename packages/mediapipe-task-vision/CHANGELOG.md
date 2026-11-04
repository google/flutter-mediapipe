## 0.1.0

The first release.

- Face Detector, Face Landmarker, Hand Landmarker, Gesture Recognizer, Pose
  Landmarker, Holistic Landmarker, Object Detector, Image Classifier, Image
  Embedder, Image Segmenter and Interactive Segmenter on Android, iOS, macOS,
  Linux, Windows and the web, through Google's official runtimes. Windows has
  no Interactive Segmenter: Google's Windows runtime takes about 25 seconds
  a stroke (UP-048).
- On 32-bit Android (armeabi-v7a) every task runs on the CPU; the GPU is not
  offered there yet.
- Image Segmenter offers only the CPU on Android: Google's Android task
  aborts the app when it reads a GPU mask on PowerVR and Adreno 630 GPUs,
  in its C library and its Java SDK alike (UP-061, UP-023).
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
  until Google says whether the change is intended (UP-057).
- On macOS, a GPU task reopens its native task after converting 1 GiB of
  frames, since Google's macOS GPU path keeps every frame until the task
  closes (UP-032 in upstream-issues.md). Tasks that reopen hold their model
  in memory, so the app may delete the model file after creating them.

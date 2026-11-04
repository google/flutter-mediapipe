# mediapipe_vision

MediaPipe vision tasks for Dart and Flutter. Use one Dart API to detect faces
and objects, track face/hand/pose landmarks, recognize gestures, classify or
embed images, and segment images. The package uses Google's official
MediaPipe task runtimes on supported platforms.

**[Try the live gallery](https://google.github.io/flutter-mediapipe/)** ·
**[See every task and platform](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-task-vision/tool/VISION_TASKS_STATUS.md)** ·
**[Browse the gallery's source](https://github.com/google/flutter-mediapipe/tree/main/gallery)**

## Tasks

| Kind | Dart classes |
| --- | --- |
| Detection | `FaceDetector`, `ObjectDetector` |
| Landmarks and gestures | `FaceLandmarker`, `HandLandmarker`, `PoseLandmarker`, `HolisticLandmarker`, `GestureRecognizer` |
| Classification and embedding | `ImageClassifier`, `ImageEmbedder` |
| Segmentation | `ImageSegmenter`, `InteractiveSegmenter` |

`InteractiveSegmenter` is Google's stateful stroke-based MagicTouch task. See
the [Interactive Segmenter guide](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-task-vision/tool/INTERACTIVE_SEGMENTER.md).

## Installation

Use **Flutter 3.47.5 stable** to match CI. The package requires Dart 3.12 or
newer and the usual toolchain for your target platform. Add the vision
package to your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  mediapipe_vision: ^0.1.0
```

To use the repository's current code instead, clone it beside your app,
depend on the package by path and point `mediapipe_core` at the clone too:

```yaml
dependencies:
  mediapipe_vision:
    path: ../flutter-mediapipe/packages/mediapipe-task-vision
dependency_overrides:
  mediapipe_core:
    path: ../flutter-mediapipe/packages/mediapipe-core
```

On Android, iOS, macOS, Linux and Windows the package's build hook bundles
Google's MediaPipe vision library. In browsers its web plugin registers
automatically and loads the pinned JavaScript/WASM runtime from jsDelivr. For offline use or a strict
Content Security Policy, see [Self-hosting the web runtime](#self-hosting-the-web-runtime).

### Self-hosting the web runtime

One setting in `mediapipe_core` covers every task family. From the app
root, `dart run mediapipe_core:web_runtime web/mediapipe` writes the
verified runtimes; then set `MediaPipeWebRuntime.baseUrl = 'mediapipe/';`
before creating a task (`mediapipe_vision.dart` exports the class). See
[core's README](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-core/README.md#web-runtime).

### Native runtimes and the task list

Every vision task runs on Google's MediaPipe vision library with no setting
(Windows has no Interactive Segmenter), which this package's hook bundles
(see [core's README](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-core/README.md)).

The `tasks` list only checks the names against the tasks validated on the
target: a Windows build fails if it names `interactive_segmenter`, which
Google's Windows library runs too slowly to offer (UP-048).

```yaml
hooks:
  user_defines:
    mediapipe_vision:
      tasks: [hand_landmarker]
```

The list is separate from `models` (below): every task needs its model listed
there, on every platform. The
[support matrix](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-task-vision/tool/VISION_TASKS_STATUS.md)
shows which tasks and delegates each platform serves.

## Quick start: detect face landmarks

Pass one of Google's pinned models as `model:`, bundled with your app at build
time. List it in your app's pubspec and declare the folder it goes in:

```yaml
flutter:
  assets:
    - assets/mediapipe/

hooks:
  user_defines:
    mediapipe_vision:
      models: [face_landmarker]
```

Then run `dart run mediapipe_core:bundle_models` from the app's root, and
again whenever the list changes. It downloads each model once, checks it
against its pinned SHA-256 and writes it into `assets/mediapipe/`, so nothing
is downloaded at run time. `VisionModels.byName` lists the accepted names.

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> detectFaces(Uint8List rgba, int width, int height) async {
  final task = await FaceLandmarker.create(
    FaceLandmarkerOptions(model: VisionModels.faceLandmarker, numFaces: 1),
  );
  try {
    final result = await task.detect(
      VisionImage.fromPixels(
        pixels: rgba,
        width: width,
        height: height,
        format: VisionPixelFormat.rgba,
      ),
    );
    for (final face in result.faceLandmarks) {
      print('${face.length} landmarks'); // 478 with the official bundle
      print('First landmark: ${face.first.x}, ${face.first.y}');
    }
  } finally {
    await task.dispose();
  }
}
```

`rgba` must contain exactly `width * height * 4` bytes. The task also accepts
RGB or BGRA pixels, with `bytesPerRow` for padded camera frames. Convert YUV
camera buffers before creating a `VisionImage`. On native platforms,
`VisionImage.fromFile('/absolute/path/photo.jpg')` lets MediaPipe decode a
file. On web, `fromFile` takes a browser-accessible URL. A Flutter asset key
is **not** a native file path or browser URL: use `rootBundle.load` for model
assets, as above.

### Models

`VisionModels` names Google's official model for every task
(`VisionModels.faceDetector`, `.handLandmarker`, `.objectDetector` and so on).
To use your own model instead, pass exactly one of `modelPath` (a native file
path, or a URL in browsers) or `modelBytes`, for example from a Flutter asset:

```dart
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<FaceLandmarker> createFromAsset() async {
  final asset = await rootBundle.load('assets/models/face_landmarker.task');
  return FaceLandmarker.create(
    FaceLandmarkerOptions(
      modelBytes: asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      ),
    ),
  );
}
```

A model that is not bundled makes `create` throw a
`RuntimeUnavailableException` whose `fix` names the pubspec entry to add. To
download models at run time instead, set `ModelStore.allowDownloads = true`
from `mediapipe_core` before creating tasks; Android release builds and
sandboxed macOS apps then need network permission, as
[platform setup](https://github.com/google/flutter-mediapipe/blob/main/doc/platform_setup.md)
describes. `ModelStore().prefetch(VisionModels.faceLandmarker)` downloads
ahead of time, on an onboarding screen say.

### Errors

Failures are `MediaPipeException`s: `RuntimeUnavailableException` when the
platform or build settings cannot run the task (its `fix` says what to
change), `ModelDownloadException` when a model cannot be fetched, and
`TaskException` when Google's runtime rejects a call, with its native
`statusCode` and `gpuUnavailable` when a GPU request was refused. Invalid
options throw `ArgumentError`, and using a disposed task `StateError`.

### Still images in other vision tasks

Create each task with `RunningMode.image` (the default), then call its
image method. For a video file's frames, create it with `RunningMode.video`
and call its video method; for a camera, create it with
`RunningMode.liveStream` and call its live stream method (see
[Video files](#video-files) and [Live cameras](#live-cameras)). The gallery
exposes a **Camera / Still image** selector for all ten tasks below on
supported platforms.

| Task | Still image | Video file frame | Live stream frame |
| --- | --- | --- | --- |
| Face Detector | `detect` | `detectForVideo` | `detectAsync` |
| Face Landmarker | `detect` | `detectForVideo` | `detectAsync` |
| Hand Landmarker | `detect` | `detectForVideo` | `detectAsync` |
| Gesture Recognizer | `recognize` | `recognizeForVideo` | `recognizeAsync` |
| Holistic Landmarker | `detect` | `detectForVideo` | `detectAsync` |
| Pose Landmarker | `detect` | `detectForVideo` | `detectAsync` |
| Object Detector | `detect` | `detectForVideo` | `detectAsync` |
| Image Classifier | `classify` | `classifyForVideo` | `classifyAsync` |
| Image Embedder | `embed` | `embedForVideo` | `embedAsync` |
| Image Segmenter | `segment` | `segmentForVideo` | `segmentAsync` |

The stroke-based `InteractiveSegmenter` works on an image with editing strokes
and has no camera mode. Choose an image in the gallery's still image mode for the
ten camera-capable tasks; the Interactive Segmenter page starts with its bundled
sample image.

## Samples for every task

Each sample is a complete function that takes a `VisionImage` (built from
pixels as in the quick start, or with `VisionImage.fromFile`), runs one
task with Google's pinned model and disposes it. In an app, create a task
once and reuse it for every image or frame.

[Face Detector](#face-detector) ·
[Face Landmarker](#face-landmarker) ·
[Hand Landmarker](#hand-landmarker) ·
[Gesture Recognizer](#gesture-recognizer) ·
[Pose Landmarker](#pose-landmarker) ·
[Holistic Landmarker](#holistic-landmarker) ·
[Object Detector](#object-detector) ·
[Image Classifier](#image-classifier) ·
[Image Embedder](#image-embedder) ·
[Image Segmenter](#image-segmenter) ·
[Interactive Segmenter](#interactive-segmenter)

### Face Detector

A box in pixels and six keypoints (eyes, ears, nose, mouth) per face.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> findFaces(VisionImage image) async {
  final detector = await FaceDetector.create(
    FaceDetectorOptions(model: VisionModels.faceDetector),
  );
  try {
    final result = await detector.detect(image);
    for (final face in result.detections) {
      final box = face.boundingBox;
      print('Face at ${box.left},${box.top}, ${box.width}x${box.height} px');
      print('Confidence ${face.categories.first.score.toStringAsFixed(2)}');
    }
  } finally {
    await detector.dispose();
  }
}
```

### Face Landmarker

478 landmarks per face (see the quick start), and optionally 52 blendshape
scores that describe the expression.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> readExpression(VisionImage image) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      outputFaceBlendshapes: true,
    ),
  );
  try {
    final result = await landmarker.detect(image);
    if (result.faceBlendshapes.isEmpty) return;
    final strongest = [...result.faceBlendshapes.first]
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final shape in strongest.take(3)) {
      print('${shape.categoryName}: ${shape.score.toStringAsFixed(2)}');
    }
  } finally {
    await landmarker.dispose();
  }
}
```

### Hand Landmarker

21 landmarks per hand, normalized to the image, with which hand it is.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> findHands(VisionImage image) async {
  final landmarker = await HandLandmarker.create(
    HandLandmarkerOptions(model: VisionModels.handLandmarker, numHands: 2),
  );
  try {
    final result = await landmarker.detect(image);
    for (var i = 0; i < result.handLandmarks.length; i++) {
      final side = result.handedness[i].first.categoryName;
      final wrist = result.handLandmarks[i].first;
      print('$side hand, wrist at ${wrist.x}, ${wrist.y}');
    }
  } finally {
    await landmarker.dispose();
  }
}
```

### Gesture Recognizer

Google's canned gestures (`Thumb_Up`, `Victory`, `Open_Palm` and more) for
each hand, with the same hand landmarks as Hand Landmarker.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> recognizeGestures(VisionImage image) async {
  final recognizer = await GestureRecognizer.create(
    GestureRecognizerOptions(model: VisionModels.gestureRecognizer),
  );
  try {
    final result = await recognizer.recognize(image);
    for (final gestures in result.gestures) {
      final top = gestures.first;
      print('${top.categoryName} (${top.score.toStringAsFixed(2)})');
    }
  } finally {
    await recognizer.dispose();
  }
}
```

### Pose Landmarker

33 body landmarks per pose, plus world coordinates in meters. Set
`outputSegmentationMasks: true` for a mask of each person.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> findPoses(VisionImage image) async {
  final landmarker = await PoseLandmarker.create(
    PoseLandmarkerOptions(model: VisionModels.poseLandmarker),
  );
  try {
    final result = await landmarker.detect(image);
    for (final pose in result.poseLandmarks) {
      final nose = pose.first;
      print('Nose at ${nose.x}, ${nose.y}, visibility ${nose.visibility}');
    }
  } finally {
    await landmarker.dispose();
  }
}
```

### Holistic Landmarker

Face, pose and both hands from one task and one pass over the image.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> trackPerson(VisionImage image) async {
  final landmarker = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(model: VisionModels.holisticLandmarker),
  );
  try {
    final result = await landmarker.detect(image);
    print('Face: ${result.faceLandmarks.length} landmarks');
    print('Pose: ${result.poseLandmarks.length} landmarks');
    print('Left hand: ${result.leftHandLandmarks.length} landmarks');
    print('Right hand: ${result.rightHandLandmarks.length} landmarks');
  } finally {
    await landmarker.dispose();
  }
}
```

### Object Detector

Labeled boxes in pixels from EfficientDet-Lite0. `maxResults` and
`scoreThreshold` trim the list; `categoryAllowlist` keeps only the labels
you name.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> detectObjects(VisionImage image) async {
  final detector = await ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      maxResults: 5,
      scoreThreshold: 0.4,
    ),
  );
  try {
    final result = await detector.detect(image);
    for (final detection in result.detections) {
      final label = detection.categories.first;
      final box = detection.boundingBox;
      print('${label.categoryName} at ${box.left},${box.top}');
    }
  } finally {
    await detector.dispose();
  }
}
```

For a complete app with a live camera, photos and videos, see the
[Object Detector guide](https://github.com/google/flutter-mediapipe/blob/main/doc/guides/vision/object_detector.md)
and its
[sample app](https://github.com/google/flutter-mediapipe/tree/main/samples/object_detection).

### Image Classifier

The most likely categories for the whole image, from EfficientNet-Lite0.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> classifyPhoto(VisionImage image) async {
  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(model: VisionModels.imageClassifier, maxResults: 3),
  );
  try {
    final result = await classifier.classify(image);
    for (final category in result.classifications.first.categories) {
      print('${category.categoryName}: ${category.score.toStringAsFixed(2)}');
    }
  } finally {
    await classifier.dispose();
  }
}
```

### Image Embedder

A feature vector per image. Compare two with cosine similarity: values near
1 mean similar content.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<double> compareImages(VisionImage first, VisionImage second) async {
  final embedder = await ImageEmbedder.create(
    ImageEmbedderOptions(model: VisionModels.imageEmbedder, l2Normalize: true),
  );
  try {
    final a = await embedder.embed(first);
    final b = await embedder.embed(second);
    return ImageEmbedder.cosineSimilarity(
      a.embeddings.first,
      b.embeddings.first,
    );
  } finally {
    await embedder.dispose();
  }
}
```

### Image Segmenter

A category for every pixel (DeepLab v3 knows 21, such as person, cat and
car), or one confidence mask per category.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> segmentScene(VisionImage image) async {
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(
      model: VisionModels.imageSegmenter,
      outputCategoryMask: true,
      outputConfidenceMasks: false,
    ),
  );
  try {
    final result = await segmenter.segment(image);
    final mask = result.categoryMask!;
    final center =
        mask.categories[mask.height ~/ 2 * mask.width + mask.width ~/ 2];
    // Labels come from the model's metadata, which may have none.
    final label = center < result.labels.length
        ? result.labels[center]
        : 'category $center';
    print('The center pixel is $label');
  } finally {
    await segmenter.dispose();
  }
}
```

### Interactive Segmenter

Select an object with strokes, in coordinates normalized to the image. The
task keeps the image, so each call passes the full stroke history; send a
shorter history to undo. `BrushMode.positive` includes what a stroke touches,
`BrushMode.negative` excludes it, and `BrushMode.lasso` selects what lies
inside the box around the stroke's points (Google's graph reads the box, not
the outline, so two opposite corners are enough). A one-point Include or
Exclude stroke draws nothing on a browser's GPU; send a short scribble
there. Not available on Windows, where Google's library takes about 25
seconds a stroke (UP-048).

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ConfidenceMask> selectObject(VisionImage image) async {
  final segmenter = await InteractiveSegmenter.create(
    InteractiveSegmenterOptions(model: VisionModels.interactiveSegmenter),
  );
  try {
    await segmenter.setImage(image);
    return await segmenter.segment([
      Stroke(
        brushMode: BrushMode.positive,
        points: [
          const NormalizedKeypoint(x: 0.45, y: 0.5),
          const NormalizedKeypoint(x: 0.55, y: 0.5),
        ],
      ),
    ]);
  } finally {
    await segmenter.dispose();
  }
}
```

The mask holds one confidence per pixel, indexed `y * width + x`, and stays
valid after the task is disposed.

## Video files

Video mode processes every frame, in order, and each call completes with its
frame's result. Use it for frames that do not run away from you, such as a
decoded video file. Create the task in video mode, then submit frames with
**strictly increasing millisecond timestamps**:

```dart
final task = await FaceLandmarker.create(
  FaceLandmarkerOptions(
    model: VisionModels.faceLandmarker,
    runningMode: RunningMode.video,
  ),
);
try {
  for (final frame in decodedFrames) {
    final result = await task.detectForVideo(
      VisionImage.fromPixels(
        pixels: frame.rgba,
        width: frame.width,
        height: frame.height,
        format: VisionPixelFormat.rgba,
      ),
      timestampMilliseconds: frame.presentationMilliseconds,
    );
    print(result.faceLandmarks.length);
  }
} finally {
  await task.dispose();
}
```

Here `decodedFrames` comes from your video decoder; the package does not
decode video. Keep a task alive across frames; do not recreate it for each
image. Pass the file's rotation as `rotationDegrees` so results come out in
display orientation, and since timestamps cannot go back, start a new task to
play a file again.

The [gallery](https://github.com/google/flutter-mediapipe/tree/main/gallery)'s
video file mode is a worked example for every camera task on all six
platforms: its
[`video_frames`](https://github.com/google/flutter-mediapipe/tree/main/gallery/packages/video_frames)
plugin decodes frame by frame with each platform's own decoder
(AVFoundation, MediaCodec, Media Foundation, GStreamer and a browser's
`<video>` element), and
[`video_file_controller.dart`](https://github.com/google/flutter-mediapipe/blob/main/gallery/lib/live/video_file_controller.dart)
runs the loop above.

## Live cameras

Live stream mode is Google's mode for cameras: each call returns at once and
the results arrive on the task's `results` stream. One frame runs at a time
and the newest one waits; a frame that arrives while another waits replaces
it, so a task slower than the camera drops frames instead of falling behind.
`droppedFrames` counts them. Tracking and smoothing are the same as in video
mode, and a frame that runs gets the result video mode would give it.

```dart
final task = await FaceLandmarker.create(
  FaceLandmarkerOptions(
    model: VisionModels.faceLandmarker,
    runningMode: RunningMode.liveStream,
  ),
);
// Listen before the first frame, as Google requires a result listener.
final results = task.results.listen((result) {
  print('${result.timestampMilliseconds}: ${result.faceLandmarks.length}');
});
cameraFrames.listen((frame) {
  task.detectAsync(
    VisionImage.fromPixels(
      pixels: frame.rgba,
      width: frame.width,
      height: frame.height,
      format: VisionPixelFormat.rgba,
    ),
    // Stamp each frame when it arrives.
    timestampMilliseconds: clock.elapsedMilliseconds,
  );
});
// Later: runs the frame in flight and the waiting one, then closes results.
await task.dispose();
await results.cancel();
```

Here `cameraFrames` and `clock` come from your camera pipeline. The checks
throw from `detectAsync` itself, and a frame's timestamp is reserved even if
the frame is then dropped. When building a frame costs time, as converting a
YUV camera image to RGBA does, submit `VisionImage.deferred(() => convert(frame))`
instead: the task calls it when it starts the frame, so a dropped frame is
never converted. Hold on to what the producer reads until then. A dropped frame never leaves the calling isolate:
no copy to the native worker, no transfer to the browser worker. `results` has one subscription; pausing it buffers
results and cancelling it discards later ones. A failure arrives on
`results` as a `TaskException`, closes the stream and fails every later call.
Google's browser runtime has no live stream mode, and the package runs the
same flow limiter on every platform in front of Google's video graph.

In browsers, `VisionImage.fromBrowserFrame(frame, width: w, height: h)` wraps
an `ImageBitmap` or video frame without copying its pixels; the task closes
it after inference, or when it drops the frame.
`BrowserOverlay.attach(task, canvas)` lets the task's worker draw landmarks
and boxes into a canvas. Both exist on every platform and throw
`RuntimeUnavailableException` off the web, so one code path compiles
everywhere. The package does not open a camera for your app. The
[gallery](https://github.com/google/flutter-mediapipe/tree/main/gallery)'s
camera mode runs every camera-capable task in live stream mode, with
rotation, mirroring, delegate switching and overlays.

## CPU and GPU

CPU is the default. For a task with a supported GPU path, request it when
creating the task:

```dart
final task = await FaceLandmarker.create(
  FaceLandmarkerOptions(
    model: VisionModels.faceLandmarker,
    delegate: Delegate.gpu,
  ),
);
```

The delegate is fixed for a task's lifetime. Await `dispose()` and create a
new task to switch delegates. A GPU initialization error is reported to your
app; it does not silently retry on CPU. GPU availability and numerical output
depend on the platform, task and model. Use
`queryFaceLandmarkerCapabilities()` or the
[support matrix](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-task-vision/tool/VISION_TASKS_STATUS.md)
before offering a GPU toggle.

| Platform | CPU | GPU path |
| --- | --- | --- |
| Web | WASM | WebGL 2 in a worker, when supported |
| iOS | Official library | Metal for supported tasks |
| Android | Official library | Supported GPUs on arm64 devices; CPU only on emulators |
| macOS Apple Silicon | Official library | Not available for now: Google's Metal results since 1.1.1 are unconfirmed (UP-057) |
| Linux x64 | Official library | OpenGL ES for supported tasks; EGL and a GPU driver required |
| Windows x64 | Official library | Not available |

The Interactive Segmenter is unavailable on Windows (UP-048). Some GPU paths
have upstream limits. Read the
[per-task matrix](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-task-vision/tool/VISION_TASKS_STATUS.md)
before depending on a particular combination.

## Runtimes, examples and troubleshooting

Native build hooks download pinned libraries and verify their digests. You do
not need to build MediaPipe or copy native libraries into a normal consuming
app. The first build needs network access for its selected runtime. Browser
tasks load the pinned JavaScript/WASM distribution from jsDelivr by default.

- [Live gallery](https://google.github.io/flutter-mediapipe/): try
  vision, audio and text tasks in a browser.
- [Gallery setup](https://github.com/google/flutter-mediapipe/blob/main/gallery/README.md): run the full Flutter application on a target device.
- [Platform status and known upstream limits](https://github.com/google/flutter-mediapipe/blob/main/packages/mediapipe-task-vision/tool/VISION_TASKS_STATUS.md): exact task availability.

If a Linux container cannot load EGL or OpenGL ES even for CPU inference,
install `libegl1` and `libgles2`. Windows builds use CPU; Google's Windows
runtime may wait for a usage-log upload during `dispose()` (see
[UP-025](https://github.com/google/flutter-mediapipe/blob/main/upstream-issues.md#up-025-windows-task-closes-wait-for-googles-usage-logging-upload)).
If you remove a face task from the `tasks` list of an existing macOS app, run
`flutter clean` once to clear its old bundled framework.

Source is Apache-2.0 licensed; the repository retains upstream notices and
runtime provenance.

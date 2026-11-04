# Object detection guide for Flutter

The MediaPipe Object Detector task lets you detect the presence and location
of multiple classes of objects, for example locating the dogs in an image.
These instructions show you how to use the Object Detector in Flutter, with
one Dart API on Android, iOS, macOS, Linux, Windows and the web. The code
sample described in these instructions is in
[`samples/object_detection`](../../../samples/object_detection/).

For more information about the capabilities, models and configuration options
of this task, see Google's
[Overview](https://developers.google.com/edge/mediapipe/solutions/vision/object_detector).

## Code example

The example code is a simple object detection app for Flutter: it uses the
camera of your device or computer to detect objects continuously, and can also
detect objects in images and videos from the device's gallery or the
computer's files. It mirrors Google's
[Android example](https://github.com/google-ai-edge/mediapipe-samples/tree/main/examples/object_detection/android),
with the same screens and settings.

You can use the app as a starting point for your own Flutter app, or refer to
it when modifying an existing app.

### Download the code

The sample lives in this repository and depends on the packages by path, so
clone the whole repository:

```sh
git clone https://github.com/google/flutter-mediapipe.git
cd flutter-mediapipe/samples/object_detection
flutter pub get
dart run mediapipe_core:bundle_models
flutter run -d <device>
```

See the sample's [README](../../../samples/object_detection/README.md) for
the requirements of each platform.

### Key components

The following files contain the code that matters for object detection:

- [`detector_helper.dart`](../../../samples/object_detection/lib/detector_helper.dart)
  creates the object detector, chooses the delegate and runs it in each
  running mode. It is the counterpart of Google's `ObjectDetectorHelper.kt`.
- [`main.dart`](../../../samples/object_detection/lib/main.dart) builds the
  app: the Camera and Gallery tabs over the settings panel.
- [`overlay.dart`](../../../samples/object_detection/lib/overlay.dart)
  draws the detection results, like Google's `OverlayView.kt`.
- [`camera_page.dart`](../../../samples/object_detection/lib/camera_page.dart)
  and [`gallery_page.dart`](../../../samples/object_detection/lib/gallery_page.dart)
  feed camera frames, photos and video frames to the helper.

## Setup

This section describes the key steps for setting up a Flutter project to use
the Object Detector. Flutter 3.47.5 stable or newer and Dart 3.12 or newer
are required.

### Dependencies

The Object Detector is in the `mediapipe_vision` package:

```yaml
dependencies:
  flutter:
    sdk: flutter
  mediapipe_vision: ^0.1.0
```

On Android, iOS, macOS, Linux and Windows the package's build hook downloads
Google's MediaPipe vision library for the target, verifies it and bundles it
with the app; you do not build MediaPipe yourself. In browsers the package
loads Google's JavaScript and WebAssembly runtime instead. The platform
projects need a few settings, such as camera permissions; see
[Platform setup](../../platform_setup.md).

### Model

The MediaPipe Object Detector task requires a trained model that is
compatible with this task. For more information on available trained models
for Object Detector, see the task overview's
[Models section](https://developers.google.com/edge/mediapipe/solutions/vision/object_detector#models).

The package pins Google's EfficientDet-Lite0 (float 32) model as
`VisionModels.objectDetector`. List it in your `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    mediapipe_vision:
      models: [object_detector]

flutter:
  assets:
    - assets/mediapipe/
```

Then run `dart run mediapipe_core:bundle_models` from the app's root. It
downloads the model, checks it against its pinned SHA-256 and writes it into
`assets/mediapipe/`, so the app downloads nothing at run time. To use a model
of your own instead, pass `modelPath` (a `.tflite` file, or a URL in
browsers) or `modelBytes` in place of `model`.

## Create the task

Use `ObjectDetector.create` to create the task. It takes
`ObjectDetectorOptions`, which set the model, the running mode and the
detection options, and returns once Google's runtime is ready. For more
information on the options, see [Configuration options](#configuration-options).

The Object Detector supports three input types: still images, decoded video
frames and live video streams. Choose the running mode that matches your
input when you create the task.

### Image

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetector> createImageDetector() => ObjectDetector.create(
  ObjectDetectorOptions(
    model: VisionModels.objectDetector,
    runningMode: RunningMode.image,
    maxResults: 5,
  ),
);
```

### Video

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetector> createVideoDetector() => ObjectDetector.create(
  ObjectDetectorOptions(
    model: VisionModels.objectDetector,
    runningMode: RunningMode.video,
    maxResults: 5,
  ),
);
```

### Live stream

In live stream mode, results arrive on the task's `results` stream instead of
a result listener. Listen before you send the first frame. An error arrives
on the same stream as a `TaskException`; it ends the stream, and the task
must be created again.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetector> createLiveDetector(
  void Function(ObjectDetectorResult result) onResult,
) async {
  final detector = await ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      runningMode: RunningMode.liveStream,
      maxResults: 5,
    ),
  );
  detector.results.listen(
    onResult,
    onError: (Object error) => print('Detection failed: $error'),
  );
  return detector;
}
```

Call `dispose()` when you are done with a task. In live stream mode it runs
the frame in flight and the waiting one, then closes `results`.

### Configuration options

This task has the following configuration options for Flutter apps:

| Option name | Description | Value range | Default value |
| --- | --- | --- | --- |
| `runningMode` | Sets the running mode for the task. There are three modes: `RunningMode.image` for single image inputs, `RunningMode.video` for decoded frames of a video, and `RunningMode.liveStream` for a live stream of input data, such as from a camera. In live stream mode, results arrive on `results`. | `{image, video, liveStream}` | `image` |
| `displayNamesLocale` | Sets the language of labels to use for display names provided in the metadata of the task's model, if available. | Locale code | `null` (the model's own locale) |
| `maxResults` | Sets the optional maximum number of top-scored detection results to return. | Any positive number, or a negative one for all results | `-1` (all results are returned) |
| `scoreThreshold` | Sets the prediction score threshold. Results below this value are rejected. | Any finite double | `0` |
| `categoryAllowlist` | Sets the optional list of allowed category names. If non-empty, detection results whose category name is not in this set are filtered out. Duplicate or unknown category names are ignored. This option is mutually exclusive with `categoryDenylist`: setting both throws an `ArgumentError`. | Any strings | Empty |
| `categoryDenylist` | Sets the optional list of category names that are not allowed. If non-empty, detection results whose category name is in this set are filtered out. Duplicate or unknown category names are ignored. This option is mutually exclusive with `categoryAllowlist`: setting both throws an `ArgumentError`. | Any strings | Empty |
| `delegate` | Sets the processor the task runs on. Check `queryObjectDetectorCapabilities()` before offering the GPU. The package does not fall back to the CPU on its own. | `{cpu, gpu}` | `cpu` |

## Prepare data

You need to convert the input image or frame to a `VisionImage` before passing
it to the Object Detector.

### Image

A photo on the device's file system can be passed by path; in browsers the
path is a URL. Encoded bytes, such as those from an image picker, can be
decoded with `dart:ui` into RGBA pixels:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:mediapipe_vision/mediapipe_vision.dart';

VisionImage imageFromFile(String path) => VisionImage.fromFile(path);

Future<VisionImage> imageFromBytes(Uint8List encoded) async {
  final codec = await ui.instantiateImageCodec(encoded);
  final picture = (await codec.getNextFrame()).image;
  codec.dispose();
  final rgba = await picture.toByteData(format: ui.ImageByteFormat.rawRgba);
  final image = VisionImage.fromPixels(
    pixels: rgba!.buffer.asUint8List(),
    width: picture.width,
    height: picture.height,
    format: VisionPixelFormat.rgba,
  );
  picture.dispose();
  return image;
}
```

### Video

Flutter has no frame-by-frame video decoder of its own. Decode the video with
a plugin that gives you each frame's pixels and its presentation time; the
sample uses the repository's `video_frames` plugin, which runs each
platform's own decoder. Then wrap each frame:

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

VisionImage videoFrame(Uint8List rgba, int width, int height) =>
    VisionImage.fromPixels(
      pixels: rgba,
      width: width,
      height: height,
      format: VisionPixelFormat.rgba,
    );
```

### Live stream

The `camera` plugin streams frames as YUV on Android and BGRA on Apple
platforms; `camera_desktop` adds macOS, Linux and Windows. Wrap each frame in
`VisionImage.deferred`, so its pixels are converted only if the detector
runs it, rather than for the frames it drops:

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

VisionImage cameraFrame(
  Uint8List bgra, {
  required int width,
  required int height,
  required int bytesPerRow,
}) => VisionImage.deferred(
  () => VisionImage.fromPixels(
    pixels: bgra,
    width: width,
    height: height,
    bytesPerRow: bytesPerRow,
    format: VisionPixelFormat.bgra,
  ),
);
```

Keep what the producer reads valid until the detector has run the frame: in
browsers, close the detector before you stop the camera. In browsers, the
sample's producer reads the `<video>` element with `createImageBitmap` and
returns `VisionImage.fromBrowserFrame`; see
[`camera_source_web.dart`](../../../samples/object_detection/lib/camera/camera_source_web.dart).
For Android's YUV frames, see
[`camera_source_native.dart`](../../../samples/object_detection/lib/camera/camera_source_native.dart).

> **Note:** Phone cameras deliver frames in the sensor's orientation. Pass
> the frame's clockwise rotation as `rotationDegrees` when you run the task,
> and turn the drawn results the same way as the preview. The sample's
> [`geometry.dart`](../../../samples/object_detection/lib/camera/geometry.dart)
> computes both.

## Run the task

Depending on the running mode, call the matching method to run inference.

### Image

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetectorResult> detectImage(
  ObjectDetector detector,
  VisionImage image,
) => detector.detect(image);
```

### Video

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ObjectDetectorResult> detectVideoFrame(
  ObjectDetector detector,
  VisionImage frame,
  Duration presentationTime, {
  int rotationDegrees = 0,
}) => detector.detectForVideo(
  frame,
  timestampMilliseconds: presentationTime.inMilliseconds,
  rotationDegrees: rotationDegrees,
);
```

### Live stream

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

final _clock = Stopwatch()..start();

void detectCameraFrame(
  ObjectDetector detector,
  VisionImage frame, {
  int rotationDegrees = 0,
}) {
  // The result arrives on detector.results.
  detector.detectAsync(
    frame,
    timestampMilliseconds: _clock.elapsedMilliseconds,
    rotationDegrees: rotationDegrees,
  );
}
```

Note the following:

- In video and live stream modes, you must provide the timestamp of each
  frame in milliseconds. Timestamps must strictly increase, so skip a frame
  whose timestamp repeats an earlier one.
- In image and video modes, `detect` and `detectForVideo` return a `Future`.
  Inference runs off the UI isolate (on a worker isolate natively, in a web
  worker in browsers), so you do not need a background thread to keep the UI
  responsive.
- In live stream mode, `detectAsync` returns at once. As in Google's
  runtime, one frame runs at a time and the newest frame waits: a frame
  submitted while another waits replaces it, and `droppedFrames` counts the
  frames replaced.

In the example code, the `detectImage`, `detectVideoFrame` and
`detectLivestreamFrame` methods of
[`ObjectDetectorHelper`](../../../samples/object_detection/lib/detector_helper.dart)
run the task in each mode.

## Handle and display results

Each run returns an `ObjectDetectorResult`: one `Detection` per object found,
each with a `boundingBox` in the input's pixels and its `categories`, highest
score first. The result also reports `imageWidth`, `imageHeight` and, in
video and live stream modes, `timestampMilliseconds`.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

void printDetections(ObjectDetectorResult result) {
  for (final (index, detection) in result.detections.indexed) {
    final box = detection.boundingBox;
    print('Detection #$index:');
    print('  Box: (left: ${box.left}, top: ${box.top}, '
        'right: ${box.right}, bottom: ${box.bottom})');
    for (final category in detection.categories) {
      print('  Category: ${category.categoryName} '
          '(score ${category.score.toStringAsFixed(2)})');
    }
  }
}
```

For the repository's
[`dog.jpg`](../../../gallery/samples/dog.jpg) (640 by 640 pixels), with
`scoreThreshold: 0.5`, it prints:

```
Detection #0:
  Box: (left: 11, top: 88, right: 523, bottom: 644)
  Category: dog (score 0.84)
```

A box can extend past the image's edges, as this one does at the bottom, so
clamp it if your drawing needs it inside.

To draw the results, map each box from the input's pixels onto your widget.
The sample's
[`DetectionPainter`](../../../samples/object_detection/lib/overlay.dart)
does this with a `CustomPainter`, including the rotation of camera frames
and the mirroring of front cameras.

## Platform notes

| Platform | CPU | GPU |
| --- | --- | --- |
| Android | Google's library | Supported GPUs on arm64 devices; CPU only on emulators |
| iOS | Google's library | Metal |
| macOS (Apple Silicon) | Google's library | Not available for now |
| Linux x64 | Google's library | OpenGL ES; EGL and a GPU driver required |
| Windows x64 | Google's library | Not available |
| Web | WebAssembly | WebGL 2, when supported |

- **GPU fallback:** creating a GPU task where the GPU is unavailable throws
  a `TaskException` whose `gpuUnavailable` is true. The sample catches it,
  tells the user and creates the task on the CPU, as Google's sample does.
- **Browsers** offer the camera only on HTTPS or `localhost`. By default the
  package loads Google's web runtime from jsDelivr; to host it yourself, see
  the vision package's
  [README](../../../packages/mediapipe-task-vision/README.md#self-hosting-the-web-runtime).

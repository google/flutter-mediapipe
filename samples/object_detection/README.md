# MediaPipe Tasks Object Detection Flutter Demo

### Overview

This is a camera app that continuously detects objects (bounding boxes,
classes and confidence) in the frames seen by your device's camera, with
Google's
[MediaPipe Object Detector](https://developers.google.com/edge/mediapipe/solutions/vision/object_detector).
It can also detect objects in images and videos from your device or computer.
One Flutter app runs on Android, iOS, macOS, Linux, Windows and the web.

It is the Flutter counterpart of Google's
[Android object detection sample](https://github.com/google-ai-edge/mediapipe-samples/tree/main/examples/object_detection/android),
with the same screens and settings:

- **Camera**: live detection in `LIVE_STREAM` mode. The detector runs one
  frame at a time and drops the frames that arrive meanwhile, as Google's
  live stream does.
- **Gallery**: pick a photo (`IMAGE` mode) or a video (`VIDEO` mode, played
  frame by frame at the file's own speed).
- **Settings**: the score threshold, the maximum number of results and the
  delegate (CPU or GPU), plus the inference time of the last frame. Changing
  a setting recreates the detector, as in Google's sample.

`lib/detector_helper.dart` holds everything MediaPipe-specific, like
`ObjectDetectorHelper.kt` in Google's sample. The rest is camera, file and
drawing code.

## Build the demo

### Prerequisites

- **Flutter 3.47.5 stable** (Dart 3.12 or newer), with the toolchain for the
  platform you build: Android SDK, Xcode, Visual Studio, or the Linux desktop
  packages.
- A clone of this repository. The sample depends on `mediapipe_vision` by path
  until the package is on pub.dev.
- Network access on the first build: the build hook downloads Google's
  MediaPipe vision library for the target and verifies its SHA-256.

| Platform | Requirement | Camera |
| --- | --- | --- |
| Android | API 28 or newer; arm64 for the GPU | `camera` |
| iOS | iOS 15 or newer; a device or an arm64 Simulator | `camera` |
| macOS | Apple Silicon, macOS 14 or newer | `camera_desktop` |
| Linux | x64 | `camera_desktop` |
| Windows | x64 | `camera_desktop` |
| Web | A browser with WebAssembly; WebGL 2 for the GPU | `getUserMedia` |

### Building

From this directory:

```sh
flutter pub get
dart run mediapipe_core:bundle_models
flutter run -d <device>
```

`bundle_models` downloads the model listed under
`hooks.user_defines.mediapipe_vision.models` in `pubspec.yaml`, verifies it and
writes it to `assets/mediapipe/`, so the app downloads nothing at run time.
Run it again after changing that list.

Use `flutter devices` to find the device name, or one of `macos`, `linux`,
`windows` or `chrome`. For the web, allow camera access when the browser asks;
browsers offer the camera only on HTTPS or `localhost`.

### Tests

```sh
flutter test
```

The tests cover the drawing and pixel code, and run Google's detector on the
host in image, video and live stream mode against the repository's
`gallery/samples/dog.jpg`.

### Models used

The sample bundles **EfficientDet-Lite0** (float 32), the model Google's
sample uses by default, as `VisionModels.objectDetector`. It detects the 80
COCO classes. To try another model, replace `model:` in
`ObjectDetectorHelper._create` with `modelPath:` (a `.tflite` file) or
`modelBytes:`.

## Platform notes

- **GPU**: the settings offer GPU only where
  `queryObjectDetectorCapabilities()` reports it. If the GPU fails when the
  detector opens, the helper says so and switches to the CPU, as Google's
  sample does; the package itself never falls back.
- **macOS GPU**: not available for now, so macOS runs on the CPU.
- **Camera rotation**: phone frames arrive in sensor layout. The sample
  passes their rotation to MediaPipe and turns the boxes upright with the
  preview.
- **Web camera frames** are read only for the frames the detector runs
  (`VisionImage.deferred`), so dropped frames cost nothing.

## License

Apache 2.0, as the rest of this repository.

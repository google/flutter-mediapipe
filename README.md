# MediaPipe Tasks for Flutter

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter" alt="Tested with Flutter 3.47.5"></a>
  <a href="https://github.com/google/flutter-mediapipe/actions/workflows/web.yaml"><img src="https://github.com/google/flutter-mediapipe/actions/workflows/web.yaml/badge.svg" alt="Web CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="Apache-2.0 license"></a>
</p>

Google's MediaPipe Tasks for Dart and Flutter on Android, iOS, macOS, Linux,
Windows and the web: detect faces and objects, track face, hand and pose
landmarks, recognize gestures, classify and embed images, text and audio,
segment images, and more. Every task runs Google's official MediaPipe
runtime for its platform, with Google's pinned models bundled at build time.

**[Try the live gallery](https://google.github.io/flutter-mediapipe/)**

## Which package do I need?

| Package | Use it for | Guide |
| --- | --- | --- |
| `mediapipe_vision` | Face and object detection; face, hand, pose and holistic landmarks; gestures; image classification, embeddings and segmentation | [Vision](packages/mediapipe-task-vision/README.md) |
| `mediapipe_text` | Text classification, embeddings (EmbeddingGemma included) and language detection; proofreading and summarization everywhere but browsers | [Text](packages/mediapipe-task-text/README.md) |
| `mediapipe_audio` | Audio classification | [Audio](packages/mediapipe-task-audio/README.md) |
| `mediapipe_decision` | Yes-or-no, choice and score questions about a text (Decision Maker), on every platform | [Decision](packages/mediapipe-task-decision/README.md) |
| `mediapipe_retrieval` | Text, images and audio in one embedding space (Universal Embedder) and an on-device vector index over them (Semantic Retriever), on every platform | [Retrieval](packages/mediapipe-task-retrieval/README.md) |

Add only the families you use: each one bundles only Google's MediaPipe
library for that family. They all depend on `mediapipe_core`, which holds the
shared download code, model store and browser runtime settings
([core guide](packages/mediapipe-core/README.md)).

## Quick start

Use Flutter 3.47.5 stable, the version CI tests (Dart 3.12 or newer). Add a
family to your app:

```yaml
# Your app's pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  mediapipe_vision: ^0.1.0
```

To use the repository's current code instead, clone it beside your app and
depend on the family by path, with `mediapipe_core` pointed at the clone too:

```yaml
dependencies:
  mediapipe_vision:
    path: ../flutter-mediapipe/packages/mediapipe-task-vision
dependency_overrides:
  mediapipe_core:
    path: ../flutter-mediapipe/packages/mediapipe-core
```

List the models your app uses in the same pubspec, and declare the folder
they are bundled in:

```yaml
flutter:
  assets:
    - assets/mediapipe/

hooks:
  user_defines:
    mediapipe_vision:
      models: [face_landmarker]
```

Then bundle them from the app's root, and again whenever the list changes:

```sh
dart run mediapipe_core:bundle_models
```

It downloads each listed model once, checks it against its pinned SHA-256 and
writes it into `assets/mediapipe/`, so the model ships inside your app:
nothing is downloaded at run time, and the app works offline from its first
launch. In CI, `dart run mediapipe_core:bundle_models --check` fails when the
folder does not match the list. Each family's `XxxModels.byName` lists the
names it accepts.

Now create a task with the bundled model:

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<int> countFaces(Uint8List rgba, int width, int height) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(model: VisionModels.faceLandmarker),
  );
  try {
    final result = await landmarker.detect(
      VisionImage.fromPixels(
        pixels: rgba,
        width: width,
        height: height,
        format: VisionPixelFormat.rgba,
      ),
    );
    return result.faceLandmarks.length;
  } finally {
    await landmarker.dispose();
  }
}
```

A model that is not bundled makes `create` throw a
`RuntimeUnavailableException` whose `fix` names the pubspec entry to add. To
download models at run time instead, add `mediapipe_core` to your
dependencies and set `ModelStore.allowDownloads = true` before creating
tasks; Android then needs the `INTERNET` permission, and a sandboxed macOS
app the network client entitlement.

On macOS, build the app for Apple Silicon only (two lines in its
`AppInfo.xcconfig`; without them, release builds fail). See
[platform setup](doc/platform_setup.md#macos). Your own models work too: pass
`modelPath` or `modelBytes` instead of `model`.

## Where it runs

| Family | Android | iOS | macOS arm64 | Linux x64 | Windows x64 | Web |
| --- | --- | --- | --- | --- | --- | --- |
| Vision | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Text (classify, embed, detect language) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Text (EmbeddingGemma) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Text (proofread, summarize) | ✓ | ✓ | ✓ | ✓ | ✓ | |
| Audio | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Decision | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Retrieval | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

CPU works everywhere a family is listed, except that browsers run Decision
and Retrieval on WebGPU alone, which needs a hardware adapter. GPU (Metal,
OpenGL ES, WebGL or Android GPU) depends on the task; Macs run the vision
tasks on the CPU for now, until Google confirms its Metal results since 1.1.1
([UP-057](upstream-issues.md#up-057-the-111-macos-library-gives-different-metal-results-from-googles-110-wheel)). Every cell is tested in CI on hosted
runners, the Android emulator, the iOS Simulator and Chromium, Firefox and
WebKit. The [vision status table](packages/mediapipe-task-vision/tool/VISION_TASKS_STATUS.md)
lists each task, delegate, known upstream limit and physical-device result.
Ask at run time with the `queryXxxCapabilities()` functions: they report the
supported delegates and why any other is unavailable.

## More

- Samples for every task:
  [vision](packages/mediapipe-task-vision/README.md#samples-for-every-task),
  [text](packages/mediapipe-task-text/README.md#quick-start),
  [audio](packages/mediapipe-task-audio/README.md#use),
  [decision](packages/mediapipe-task-decision/README.md#quick-start) and
  [retrieval](packages/mediapipe-task-retrieval/README.md#quick-start).
- [Object detection guide](doc/guides/vision/object_detector.md), with a
  [sample app](samples/object_detection/) for every platform, following
  Google's Android guide and sample.
- [Platform setup](doc/platform_setup.md): permissions, entitlements, minimum
  OS versions, offline builds and browser hosting.
- [Privacy and licenses](doc/privacy_and_licenses.md): what is downloaded, from
  where, and under which license.
- [Migration](MIGRATION.md) from Google's `mediapipe_text` and
  `mediapipe_core` 0.0.1 previews.
- [Gallery](gallery/README.md): the full demo app, also
  [live on GitHub Pages](https://google.github.io/flutter-mediapipe/).
- [Contributing](CONTRIBUTING.md), including how to add a task.

## Origin and license

Source is licensed under [Apache-2.0](LICENSE), with upstream notices
retained.

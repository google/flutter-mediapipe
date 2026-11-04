# MediaPipe Gallery

One app for the interactive MediaPipe demos this repository supports on the
platform you run it on. A task appears as a tile only when its runtime is
bundled, its support is validated here, and it has a screen to show.

## Running it

**Web:** [try the gallery](https://google.github.io/flutter-mediapipe/),
or run `dart run tool/gallery_builder/bin/prepare_gallery.dart --target web`
from the root, then `cd gallery && flutter run -d chrome --release`. Supported vision tasks use
Google's pinned official JS/WASM runtime on a worker; GPU tasks use WebGL 2.
Allow camera
access on HTTPS or localhost. See [web tests and deployment](tool/WEB_FACE.md).

The pubspec and assets are generated, because the task list is per target and
the build hook rejects a task it has no runtime for. On a Mac with Apple
Silicon, a clean checkout needs only Flutter and Xcode:

```sh
dart run tool/gallery_builder/bin/prepare_gallery.dart --target macos/arm64
cd gallery
flutter run -d macos --release
```

The gallery bundles its models the way the packages ask any app to: the
preparer lists each task's model under `hooks.user_defines.<family>.models` in
the generated pubspec and runs `dart run mediapipe_core:bundle_models`, which
downloads each one, verifies it against its pinned SHA-256 and writes it into
`assets/mediapipe/`. The demos pass the pins (`VisionModels`, `TextModels`,
`AudioModels`) and core finds the bundled copies, so nothing is downloaded at
run time. A failed download fails the preparation rather than building an
incomplete app; a rerun keeps the models already verified. Vision, text and
audio each bundle Google's MediaPipe library for that family. Until Google
publishes those libraries, pass `--asset-source <directory>` (a directory
holding them named by SHA-256) to the preparer. The checked-in macOS
project already pins the build to arm64 and declares the camera entitlement
and usage description.

The same command prepares every target: `ios/arm64`, `ios-simulator/arm64`,
`linux/x64`, `windows/x64`, `android/arm64`, `android/x64` and `web`. The
checked-in iOS project already excludes the x86_64 simulator slice and
declares the camera and photo usage descriptions, none of which
`flutter create` provides.

For Android, a clean checkout needs only Dart, Flutter and the Android SDK:

```sh
dart run tool/gallery_builder/bin/prepare_gallery.dart --target android/arm64
cd gallery
flutter run -d <device-id> --release
```

The Dart preparer generates the gallery's configuration and bundles every
required model the same way, and fails rather than building an incomplete
APK. `flutter run` builds, installs and launches the release app on the
connected phone; the APK remains at `gallery/build/app/outputs/flutter-apk/app-release.apk`.
Every task runs on Google's MediaPipe library for its family, and camera
frames are converted from YUV in Dart. Phones offer the GPU where a task has
one; an emulator offers only the CPU. Test Lab runs on a physical Pixel 7
validated both delegates and front/back camera capture on Google's earlier
Java SDK; [the Android Test Lab guide](tool/ANDROID_FACE_TESTLAB.md) runs them
without owning an Android device.

For Windows x64 and Linux x64, prepare with `--target windows/x64` or
`--target linux/x64`, then run `flutter run -d windows --release` or
`flutter run -d linux --release`. Linux offers GPU for the live Face and Hand
Landmarker demos; Windows and the Pose demo use CPU only.
Each family's hook bundles Google's checksum-pinned library for that family.
`camera_desktop` provides native
Media Foundation capture on Windows and GStreamer/V4L2 capture on Linux.
Linux builds need `libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev` and
`gstreamer1.0-plugins-good` in addition to Flutter's desktop dependencies, and
video file mode needs `gstreamer1.0-libav` to decode H.264.

## What decides the tiles

Three gates, in order:

1. **Bundled**: the preparer selects the tasks whose runtime this target can
   actually obtain: the vision tasks `vision_tasks.dart` validates there, the
   text and audio tasks, and in browsers the tasks Google's JavaScript runtime
   serves. Every target bundles every task it can, `--tasks` narrows the
   list. EmbeddingGemma, the Proofreader and the
   Summarizer add 419 MB of models, so a native gallery is about 770 MB;
   their integration suite compares with Google's references from
   `--modern-text-reference` or the text package's checked-in fixtures.
   **The web gallery has no Proofreader or Summarizer**: Google's browser
   runtime does not include them
   ([UP-034](../upstream-issues.md#up-034-browser-text-runtime-omits-proofreader-and-summarizer)),
   so the web build bundles EmbeddingGemma alone and shows the other two as
   cards that say why. Decision Maker and its game, Hungry Fish, bundle no
   model: Laya (678 MB) and EmbeddingGemma 2 (165 MB) download on first use, verified into the model cache natively and fetched
   by Google's runtime in browsers, which show the two only on a hardware
   WebGPU adapter
   ([UP-049](../upstream-issues.md#up-049-the-browser-decision-maker-fails-every-evaluation-without-a-hardware-webgpu-adapter)).
2. **Validated**: `lib/catalog.dart` asks the package's own capability query.
   Nothing restates support by hand, so a task validated on a new platform
   appears here with no code change.
3. **Demonstrable**: a screen of its own, which is what `GalleryDemo` names.
   Entries without one are known to the gallery but never become tiles.

Tasks without a validated runtime or a screen do not appear as tiles. The
package's status table below records their support details.

The visible tiles depend on the target and follow the package's
[status table](../packages/mediapipe-task-vision/tool/VISION_TASKS_STATUS.md):
each validated task with a screen appears, including the MagicTouch stroke
editor wherever its runtime runs.

## Gemma models

EmbeddingGemma, the Proofreader and the Summarizer are Gemma models, under the
[Gemma Terms of Use](https://ai.google.dev/gemma/terms) and its
[Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy)
rather than Apache 2.0. The gallery passes the terms on as the terms ask:
each of these pages, and its Info dialog, says that Gemma is provided under
and subject to them and links to both. Anyone redistributing a gallery build
takes on the same terms.

## Live camera

`lib/live/` shares camera capture, live stream inference, timings, camera
switching, stop/start, cleanup and overlay geometry across live tasks. Every
camera frame is stamped when it arrives and submitted to the task in live
stream mode, which runs one frame at a time with the newest one waiting and
drops the rest, as Google's live stream does; native frames are converted only
when the task starts them (`VisionImage.deferred`), browser frames when they
arrive; the Stats card shows the
inference time and the frames dropped per second. It handles desktop RGBA,
Apple BGRA and Android YUV camera buffers. Every camera-based vision page also
has a **Mode** selector. Choose **Still image** to open a JPG, PNG or WebP file
and run IMAGE-mode inference with the same model, settings and CPU/GPU
delegate. Choose **Video file** to run a clip through the task in video mode:
every frame in order, with the file's own timestamps and rotation, a bundled
three-second clip (`samples/scene.mp4`) or a file you pick. Play, pause and
restart only, since video mode's timestamps cannot go back. The frames come
from `packages/video_frames`, the gallery's own plugin over each platform's
decoder: AVFoundation on iOS and macOS, MediaCodec on Android, Media
Foundation on Windows, GStreamer on Linux, and in browsers a `<video>` element
stepped one frame at a time. The vision package decodes nothing.
Switching back to **Camera** reopens the live stream task. Interactive Segmenter is image-only and uses its own editor.
Windows exposes CPU only. Face and Hand Landmarker also expose GPU on Linux,
Apple platforms, Android phones and web.
Web uses browser-native capture and transferable bitmaps while sharing these
controls and the same overlay painter. Web GPU requires worker WebGL 2 support.

## Tests

```sh
cd gallery
flutter test -d macos integration_test/assets_test.dart
flutter test -d macos integration_test/runtime_test.dart
flutter test -d macos integration_test/vision_still_image_modes_test.dart
```

Run one file per invocation: `flutter test -d macos integration_test/` cannot
start a second app instance on the device and fails to load the later file.

These check the bundle the app was actually built with: that every visible tile
can load its model and sample, that the live demo's model resolves, and that
all ten camera vision demos process their sample in still image mode. The
tests derive their asset names from the catalog, so they cannot drift from
what the screens ask for.

The Desktop tasks workflow also builds the actual Windows/Linux gallery,
checks native camera plugin registration and enumeration, visits all live task
runtimes in one process, and drives the Face Landmarks page with supplied portrait
frames through Google's real CPU task. It checks padded RGBA/BGRA, 478-point
results, camera switching, stop/start, cleanup and a release gallery build.
Hosted runners have no physical webcam, so the real-camera workflows supply one:
Linux streams the licensed portrait into a v4l2loopback device and Windows
registers a Media Foundation virtual camera showing it (`tool/windows/vcam`).
Both run `integration_test/real_camera_test.dart`, which checks capture, a face
across stop/restart, and overlay alignment against the on-screen preview; the
status matrix links the records. A physical webcam still differs in formats and
exposure, so a manual pass remains useful: run the gallery's Face Landmarker page
to check capture, preview mirroring and visual landmark alignment.

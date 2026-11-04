# MagicTouch Interactive Segmenter

`InteractiveSegmenter` wraps Google's stateful MagicTouch pipeline: the
current image-and-strokes API, not the legacy one-point ROI wrapper. The
complete official model bundle and native inference graph are preserved. It
runs through Google's own runtime on each platform:

- **Android, iOS, macOS arm64 (14+), Linux x64:** Google's 1.2.0 vision
  library, which the vision package's hook bundles.
- **Web:** `@mediapipe/tasks-vision` 1.2.0-rc.20261018.

Browsers run it on CPU or WebGL 2, every other platform on the CPU. Google's
Windows library exports the stateful API as well and its masks agree with the
macOS wheel's within 0.045, but a stroke takes about 25 seconds on GitHub's
Windows runner and Google's Windows Python wheel lacks the API, so Windows
has no Interactive Segmenter (upstream-issues.md UP-048).

Official sources:

- [Overview and model](https://developers.google.com/edge/mediapipe/solutions/vision/interactive_segmenter)
- [Python API and full stroke history](https://developers.google.com/edge/mediapipe/solutions/vision/interactive_segmenter/python)
- [MediaPipe 1.0.1 distribution](https://pypi.org/project/mediapipe/1.0.1/)

## Consumer configuration

Bundle Google's model with the app in its `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/mediapipe/

hooks:
  user_defines:
    mediapipe_vision:
      models: [interactive_segmenter]
```

Then run `dart run mediapipe_core:bundle_models` from the app's root. The model
is Google's unchanged **30.5 MB** int8 version-1 bundle
(`VisionModels.interactiveSegmenter`,
`interactive_segmenter_v2/magic_touch/int8/1/interactive_segmentation.task`,
SHA-256 `38431bc66b883404e8397f74c3579404315b9b52b04a46c6346fe906a7309b03`).
Maintainers download it with `dart tool/download_models.dart interactive_segmenter`.

No platform needs a setting, and the task needs no entry in
`mediapipe_vision.tasks`.

On macOS, set the deployment target to **14.0** and add `ARCHS = arm64` and
`EXCLUDED_ARCHS = x86_64` to `macos/Runner/Configs/AppInfo.xcconfig`; Google's
library requires macOS 14.0. Intel Macs are not supported.

## Dart API

```dart
final task = await InteractiveSegmenter.create(
  InteractiveSegmenterOptions(
    model: VisionModels.interactiveSegmenter,
    delegate: Delegate.cpu,
  ),
);
try {
  await task.setImage(VisionImage.fromFile('/absolute/path/photo.jpg'));
  final history = [
    Stroke(
      brushMode: BrushMode.positive,
      points: [const NormalizedKeypoint(x: 0.66, y: 0.55)],
    ),
  ];
  final mask = await task.segment(history);
  // Unmodified float32 foreground confidence at (x, y):
  print(mask.confidence[100 * mask.width + 150]);
} finally {
  await task.dispose();
}
```

`modelPath` or `modelBytes` take a model of your own instead of the bundled
one. `setImage` also accepts RGB/RGBA/BGRA pixels with optional row padding. The wrapper removes padding and converts BGRA;
Google's pipeline performs all model preprocessing and inference.

Call `setImage` once per image, then pass the **complete current stroke history**
to every `segment` call. Points are normalized to the input image, excluding
canvas letterboxing. A positive click is a one-point positive stroke. Negative
strokes exclude areas. A lasso selects what lies inside the box around its
points, however many: Google's graph reads the box, not the outline. Set
`isCompleted: false` while drawing and resubmit the finished stroke with
`isCompleted: true` when released; send a lasso only when released, since
Google's CPU graph reads an unfinished one differently. Undo by resubmitting
a shorter history. Every mode takes a stroke of one or more points, as
Google's API does.

Clear the displayed mask when the history becomes empty, and call `setImage`
to reset the session. Empty histories are rejected before native execution:
the upstream decoder fails with an input tensor count mismatch on empty input.
After a native segment error, a new successful `setImage` is required.
Validation errors do not poison the native session.

The persistent worker serializes requests in submission order. Results own
their confidence buffers and remain valid after another inference or disposal.
No threshold, smoothing or postprocessing is added to the task result.
`dispose` drains queued work and is idempotent.

## How Google's graph reads strokes

Measured on 2026-10-07 with the pinned model on `cats_and_dogs.jpg`:
natively on macOS through the package's FFI bindings, which could send what
Google's API takes but the Dart type then rejected, and in headless Chromium
through Google's `@mediapipe/tasks-vision` 1.0.1 on the CPU and WebGL
delegates. The native run used the fixtures' 299 x 150 raw input and the
browser the 1200 x 600 JPEG it decoded, so foreground shares differ between
columns; comparisons hold within a column. Google's Python wheel confirmed
the lasso and Exclude rows when it regenerated the fixtures.

| Case | Native CPU | Web CPU | WebGL |
| --- | --- | --- | --- |
| Open rectangle lasso vs the closed one | identical | identical | identical |
| Two opposite corners vs the rectangle | identical | identical | identical |
| Three collinear points vs the rectangle | identical | identical | identical |
| Unfinished lasso vs the finished one | foreground 0.063 vs 0.131 | agreement 0.84 | agreement 0.9996 |
| Unfinished Include or Exclude vs finished | identical | identical | agreement 0.9996 |
| A single-point stroke of any mode | as Google's samples | as Google's samples | the default mask: a point draws nothing |
| The editor's 13-point ring vs the point | agreement 0.9999 | agreement 0.9999 | ring works, point does not |
| Exclude with no Include before it | foreground 0.034 | foreground 0.021 | the default mask |
| Rectangle lasso, CPU vs WebGL | | | agreement 0.984 |
| Brush mode 0 or 7 | "Unknown brush mode" error; `setImage` recovers | | |

So a lasso is the bounding box of its points, closing the outline changes
nothing, and Google's three samples (Android, iOS and the web demo) send
strokes as drawn with no minimum and no closing point, segmenting only when
the pointer lifts. The web demo drops strokes shorter than 0.05 of the image.
This package follows Google's API (`Stroke` takes one or more points in any
mode) and its samples in the editor below. The package's own tests check the
box rule pixel for pixel (`raw-lasso-open` and `raw-lasso-corners` reproduce
`raw-lasso`'s mask, `raw-negative-partial` reproduces `raw-negative`'s), the
browser suite checks it on Google's own JavaScript output, and the phone
suite checks it on the whole photo.

## Editor

The gallery's Segment page (`gallery/lib/segment_page.dart`, with its editor in
`gallery/lib/segment/`) is the MagicTouch editor on every platform: Google's
three brushes under the picture (Include, Exclude and Lasso), undo, clear and
a display-only threshold setting on the bundled sample photo. The tap area
takes the picture's exact shape, so a tap's position is measured against the
picture, not the letterbox.

Include and Exclude strokes are segmented while they are drawn, as Google
reads them the same finished or not; a tap becomes a 13-point ring, because
a browser's WebGL graph draws nothing for a single point. A lasso is drawn
until the pointer lifts and then sent as drawn, unclosed, like Google's
samples; one shorter than 0.05 of the image is dropped, so a tap in lasso
mode selects nothing. Finished strokes stay painted in their brush's color
(Include in the design's accent, Exclude red, Lasso blue with a light fill),
and the Selection card counts them ("1 include · 1 exclude · 1 lasso").

A failed request keeps the picture, the strokes and the last mask, and a
banner over the picture says what failed. The next stroke sets the image
again before it asks, since a failure can leave Google's graph needing it,
and a success removes the banner. Each failure is printed with the delegate
and the history sent (`Segment GPU: segment failed for [positive 13 points,
negative 8 points in progress]: ...`), so a browser's console keeps it.

Inference has one active request and one replaceable pending history. Drawing
does not enqueue every pointer event. Image replacement, undo and clear discard
obsolete results. Mask coloring runs off the UI isolate. Timings show the
public async inference call and mask conversion/upload separately.
This is a still-image editor; camera capture and temporal object tracking are
not part of the Interactive Segmenter API.

## GPU status

`queryInteractiveSegmenterCapabilities()` (exported by
`mediapipe_vision.dart`) returns supported delegates,
required macOS version/architecture and unavailable-delegate explanations. It
does not load a model. Creation checks the same support information before
starting a worker. The shared
[four-task validation tool](../../../tool/task_benchmarks/README.md) measures
repeated strokes, image replacement, reloading and process memory alongside the
three modern text tasks.

`Delegate.gpu` runs in browsers only, on WebGL 2 as Google's sample does;
elsewhere `create` refuses it with a `RuntimeUnavailableException`. Google's
mobile SDKs run the task on the CPU. On macOS, Google's
`HeatmapFromStrokesCalculatorGl` requests GLSL 330 in a macOS OpenGL 2.1
context and fails to compile its shader, in both the 1.0.0 and 1.0.1 runtimes
(upstream-issues.md UP-008). This was reproduced using the official Python API
with valid RGBA input outside the sandbox. Linux's GPU path aborts (UP-029).
Enabling Metal for the face tasks does not repair this separate stroke graph.
There is no silent CPU fallback and no modified substitute pipeline.

## Native provenance

The package binds the modern stateful API in Google's vision library
(`package:mediapipe_vision/mediapipe.dylib`) on macOS, Linux and iOS. Its
bindings are generated with the other vision tasks' from Google's
`vision/interactive_segmenter/interactive_segmenter.h`, which Google's
headers ship since the October 16 build, and `tool/abi_check.cc` checks their
struct sizes. Tests also compare the sizes and field offsets with Google's
Python ctypes definitions.

The vision package's hook bundles Google's library unmodified except on macOS,
where it shortens the system framework paths and signs the copy again to make
room for Flutter's install name
([UP-042](../../../upstream-issues.md#up-042-per-family-macos-and-simulator-libraries-have-no-header-room-for-a-rename)).
Consumers need Flutter and Xcode, but no Python, Bazel, CMake or credentials
for native downloads.

## Validation and measurements

The saved macOS validation and CPU baseline, in git history at `3e217ac` under
`tool/validations/2026-09-12-interactive-segmenter/`, include the public-release
consumer report and editor screenshot.

- `dart test test/interactive_segmenter_test.dart` compares every mask pixel in
  20 cases with Google's Python API (the 1.1.0 wheel) at maximum absolute
  error 1e-6: clicks, partial strokes, multiple selections, exclusion, lasso
  as an outline, open, and as two corners, an unfinished Exclude, an Exclude
  drag finished and in progress, an unfinished lasso, a lasso with an
  Exclude drag, two lassos, Include, lasso and Exclude together, undo, image
  replacement, blank input, padded RGB/RGBA/BGRA, ownership and lifecycle.
  The unfinished lasso is the only case the completed flag changes, so it is
  what fails if a wrapper drops that flag.
  It also runs the segmenter alongside CPU and Metal face tasks.
- `gallery/test/segment_editor_controller_test.dart` checks the editor's
  bounded queue, late-result rejection, undo/clear, the lasso sent unclosed
  on release and dropped when too short, the Exclude stroke sent while drawn,
  the stroke counts, the ring a tap becomes and the display threshold. The
  gallery journey (`gallery_journey_test.dart`, and its browser twin
  `gallery/tool/browser/test_gallery_journey.mjs`) taps Include, drags
  Exclude and a lasso, reads the Selection card, undoes and clears on the
  Segment page, on every delegate the page offers.
- The gallery's `sdk_interactive_segmenter_test` (iOS Simulator, Android
  emulator and Test Lab phones) compares Include with Google's `file-cat`
  mask and Exclude and Lasso with the fixture's summaries of the same photo,
  and checks that the lasso's outline and corners select the same pixels.
  The Exclude summary is a drag that removes most of the dog: dropping it
  would miss by about 0.12 of mean cell error, against a tolerance of 0.02.
- The browser suite (`gallery/tool/web_api_probe.dart` through
  `test_browser.mjs`) compares Include, Exclude, lasso and an unfinished
  stroke with Google's JavaScript on the same delegate, CPU and WebGL, and
  checks the box rule on Google's own output.

`generate_interactive_segmenter_reference.py` runs Google's wheel pinned for
the host (core's `tool/official_wheels.py`); `--python-package-root` takes the
fully extracted pinned wheel instead. Ordinary consumer/test inference never
loads Python. Fixture attribution and ABI provenance are in
[the reference notes](../test/fixtures/interactive_segmentation/README.md).

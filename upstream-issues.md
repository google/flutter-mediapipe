# Upstream issues and runtime compatibility findings

Last updated: 2026-10-14. These are local observations unless explicitly marked
as an external report; each entry says whether it was reported upstream. An
exported symbol alone does not establish a working task or platform.

## Runtimes

The packages run Google's per-family MediaPipe libraries, a pre-release 1.1.1
development build of October 9, 2026 (core's `family_runtimes.dart`; the
1.1.0 development builds of October 5 and 8 before it), on Android, iOS,
macOS, Linux and Windows, and Google's JavaScript runtime 1.0.1 in browsers.
Their outputs are compared with Google's 1.1.0 release candidate
wheel, `mediapipe-nightly` 1.1.0rc20260925 (core's `reference_wheels.dart`).
With Google's agreement they are posted unmodified, for testing, as the
pre-release `per-family-v1.1.1-dev.20261009` on
`hugocornellier/mediapipe_flutter_native`, which the hooks download. CI runs
them on Linux x64, Windows x64, macOS arm64, the arm64 iOS Simulator and the
x86_64 Android emulator, and Firebase Test Lab on a Pixel 8a (Mali), a Galaxy
S24 (Adreno) and a Galaxy A12 (PowerVR); they also ran on an iPhone 15 Pro and
an arm64 Android emulator. An entry observed only on an earlier release says
so, and may no longer apply.

## Current issues

What still applies to Google's 1.1.0 libraries, its Python reference API or
its browser runtime. "Not re-tested" entries were observed on 1.0.x and are
kept, with their workarounds, until someone checks them on 1.1.0.

| Entry | Finding | On 1.1.0 |
| --- | --- | --- |
| [UP-005](#up-005-googles-python-writes-holistic-thresholds-in-the-wrong-order) | Google's Python writes Holistic thresholds in the wrong order | Present: the 1.1.0rc20260924 nightly's Python |
| [UP-006](#up-006-holistic-mask-smoothing-retains-dimensions-across-image-requests) | Holistic mask smoothing retains dimensions across IMAGE requests | Not re-tested |
| [UP-008](#up-008-stateful-interactive-segmenter-gpu-stroke-shader-fails-on-macos) | Stateful Interactive Segmenter GPU stroke shader fails on macOS | Present (re-tested) |
| [UP-009](#up-009-image-segmenter-creation-crashes-on-a-null-display-names-locale) | Image Segmenter creation crashes on a null display-names locale | Not re-tested |
| [UP-010](#up-010-segmentation-tasks-reject-a-region-of-interest) | Segmentation tasks reject a region of interest | Not re-tested; expected behavior |
| [UP-013](#up-013-holistic-image-results-depend-on-earlier-image-calls) | Holistic IMAGE results depend on earlier IMAGE calls | Not re-tested |
| [UP-015](#up-015-pose-gpu-treats-rotated-input-differently-from-pose-cpu) | Pose GPU treats rotated input differently from Pose CPU | Not re-tested |
| [UP-017](#up-017-image-segmenter-stretches-the-upright-mask-over-a-rotated-input) | Image Segmenter stretches the upright mask over a rotated input | Not re-tested |
| [UP-023](#up-023-android-image-segmenter-gpu-aborts-on-a-powervr-gpu) | Android Image Segmenter GPU aborts on a PowerVR GPU | Not re-tested: the GPU stays withdrawn on PowerVR |
| [UP-025](#up-025-windows-task-closes-wait-for-googles-usage-logging-upload) | Windows task closes wait for Google's usage-logging upload | Present on Android phones with the 1.2.0 nightly of October 18; not yet raised |
| [UP-026](#up-026-holistic-cannot-open-its-face-blendshapes-model-on-a-desktop-or-iphone-gpu) | Holistic cannot open its face blendshapes model on a desktop or iPhone GPU | Present (iPhone, macOS and Android) |
| [UP-027](#up-027-linux-image-embedder-aborts-on-opengl-es) | Linux Image Embedder aborts on OpenGL ES | Not re-tested |
| [UP-028](#up-028-pose-segmentation-masks-fail-on-metal) | Pose segmentation masks fail on Metal | Present (re-tested) |
| [UP-029](#up-029-linux-stateful-interactive-segmenter-aborts-on-opengl-es) | Linux stateful Interactive Segmenter aborts on OpenGL ES | Not re-tested |
| [UP-030](#up-030-linux-pose-masks-on-opengl-es-are-8-bit-rgba-images) | Linux Pose masks on OpenGL ES are 8-bit RGBA images | Not re-tested |
| [UP-031](#up-031-ios-sdk-gpu-tasks-abort-on-the-ios-simulator) | iOS SDK GPU tasks abort on the iOS Simulator | Present (simulator) |
| [UP-032](#up-032-macos-gpu-tasks-keep-every-frame-until-they-close) | macOS GPU tasks keep every frame until they close | Present (re-tested) |
| [UP-034](#up-034-browser-text-runtime-omits-proofreader-and-summarizer) | Browser text runtime omits Proofreader and Summarizer | Browser runtime 1.0.1 |
| [UP-036](#up-036-ios-summarizer-generations-drift-from-googles-wheel-late-in-long-summaries) | iOS Summarizer generations drift from Google's wheel late in long summaries | Present: the libraries part from the wheel late on most hosts, and long key-point summaries vary from run to run |
| [UP-037](#up-037-the-audio-streams-flushed-tail-is-stamped-with-a-sentinel-not-a-time) | The audio stream's flushed tail is stamped with a sentinel, not a time | Present |
| [UP-038](#up-038-the-c-audio-stream-callback-carries-no-user-data-and-no-message) | The C audio stream callback carries no user data and no message | Present |
| [UP-041](#up-041-two-defects-in-the-c-audio-classifier) | Two defects in the C Audio Classifier | Not re-checked |
| [UP-042](#up-042-per-family-macos-and-simulator-libraries-have-no-header-room-for-a-rename) | Per-family macOS and simulator libraries have no header room for a rename | Fixed in the 1.1.1 build of October 9 |
| [UP-043](#up-043-per-family-libraries-each-define-the-same-objective-c-classes) | Per-family libraries each define the same Objective-C classes | Found on 1.1.0 |
| [UP-044](#up-044-apple-gpu-tasks-abort-on-a-three-channel-image-instead-of-failing) | Apple GPU tasks abort on a three-channel image instead of failing | Found on 1.1.0 |
| [UP-045](#up-045-per-family-windows-libraries-export-tensorflow-lite-and-litert) | Per-family Windows libraries export TensorFlow Lite and LiteRT | Found on 1.1.0 |
| [UP-046](#up-046-face-detectors-gpu-needs-a-litert-plugin-the-linux-and-android-libraries-do-not-ship) | Face Detector's GPU needs a LiteRT plugin the Linux and Android libraries do not ship | Found on 1.1.0 |
| [UP-047](#up-047-opengl-es-gpu-category-masks-come-back-as-float32) | OpenGL ES GPU category masks come back as float32 | Found on 1.1.0 |
| [UP-048](#up-048-the-windows-library-runs-the-stateful-interactive-segmenter-about-100-times-slower-than-linux) | The Windows library runs the stateful Interactive Segmenter about 100 times slower than Linux | Found on 1.1.0 |
| [UP-049](#up-049-the-browser-decision-maker-fails-every-evaluation-without-a-hardware-webgpu-adapter) | The browser Decision Maker fails every evaluation without a hardware WebGPU adapter | Found on 1.1.0 |
| [UP-050](#up-050-universal-embedder-refuses-the-text-only-embeddinggemma-2-model) | Universal Embedder refuses the text-only EmbeddingGemma 2 model | Found on 1.1.0 |
| [UP-051](#up-051-the-browser-universal-embedder-reads-modelassetpath-as-a-file-and-a-second-wasm-object-needs-the-loader-again) | The browser Universal Embedder reads modelAssetPath as a file, and a second Wasm object needs the loader again | Found on 1.1.0 |
| [UP-052](#up-052-the-browser-universal-embedder-runs-only-on-a-hardware-webgpu-adapter) | The browser Universal Embedder runs only on a hardware WebGPU adapter | Found on 1.1.0 |
| [UP-053](#up-053-the-per-family-decision-library-fails-every-evaluation-with-the-text-only-embeddinggemma-2-model) | The per-family decision library fails every evaluation with the text-only EmbeddingGemma 2 model | Fixed in the 1.2.0 nightly of October 18 |
| [UP-054](#up-054-in-webkit-the-browser-runtime-embeds-every-input-as-zeros-with-embeddinggemma-2) | In WebKit, the browser runtime embeds every input as zeros with EmbeddingGemma 2 | Found on 1.1.0, still in the 1.2.0 nightlies of October 18 and 21; on the October 20 agenda |
| [UP-055](#up-055-the-browser-decision-maker-aborts-while-it-creates-the-task-with-gliner25-decide) | The browser Decision Maker aborts while it creates the task with GLiNER2.5-Decide | Found on 1.1.0; on the October 20 agenda |
| [UP-056](#up-056-the-browser-decision-maker-ignores-normalizeprior-and-scoringmode) | The browser Decision Maker ignores normalizePrior and scoringMode | Found on 1.1.0; on the October 20 agenda |
| [UP-057](#up-057-the-111-macos-library-gives-different-metal-results-from-googles-110-wheel) | The 1.1.1 macOS library gives different Metal results from Google's 1.1.0 wheel | Found on the 1.1.1 build of October 9 and the 1.1.1 nightly |
| [UP-058](#up-058-universal-embedders-audio-embeddings-change-from-call-to-call) | Universal Embedder's audio embeddings change from call to call | Found on 1.1.0, still on the 1.2.0 nightly of October 18; raised October 20, Google is looking into it |
| [UP-059](#up-059-with-the-flutter-host-environment-the-usage-log-drops-the-os) | With the Flutter host environment, the usage log drops the OS | Fixed in the 1.2.0 nightly of October 18 |
| [UP-060](#up-060-decision-maker-and-universal-embedder-reserve-memory-for-their-whole-token-budget) | Decision Maker and Universal Embedder reserve memory for their whole token budget | Found on the 1.1.1 build of October 9; worked around |
| [UP-061](#up-061-image-segmenters-gpu-mask-aborts-the-app-when-it-is-read-on-a-pixel-3) | Image Segmenter's GPU mask aborts the app when it is read, on a Pixel 3 | Found on the 1.1.1 build of October 9; worked around |
| [UP-062](#up-062-the-ios-libraries-call-required-reason-apis-and-ship-no-privacy-manifest) | The iOS libraries call required-reason APIs and ship no privacy manifest | Found on the 1.1.1 build of October 9; worked around in the gallery |
| [UP-063](#up-063-semantic-retrievers-usage-uploads-carry-no-os-host-environment-or-host-version) | Semantic Retriever's usage uploads carry no OS, host environment or host version | Present on the 1.2.0 nightly of October 18 and in Google's Python; raised October 20, Google is looking into it |
| [UP-064](#up-064-the-umbrella-headers-have-no-license-text-and-the-audio-classifier-header-misstates-it) | The umbrella headers have no license text, and the Audio Classifier header misstates it | Present on the 1.2.0 nightly of October 18; raised October 20, Google will fix it |

### UP-005: Google's Python writes Holistic thresholds in the wrong order

**Status:** confirmed 2026-09-24 on the macOS 1.0.0 wheel and 1.1.0rc20260924
nightly, and on the pinned Linux 1.0.1 and Windows 1.0.0 wheels (CI run
36009377156). Fixed in this repository; not reported upstream.

After the three face thresholds, the public header's `MpHolisticLandmarkerOptions`
places `min_hand_landmarks_confidence` before the three pose thresholds. The
wheels' Python ctypes place it after them. The compiled library, including the
wheels' own copy, reads the header's order, so Google's Python applies every
non-default threshold to the wrong field: pose detection lands on the hand
threshold, suppression on pose detection, pose landmarks on suppression, and hand
on pose presence. The defaults are all `0.5` in both APIs, which hides it.

A probe, `tool/holistic_threshold_order_probe.py` (in git history at `3e217ac`),
showed this by setting one threshold at a time to an extreme value on
`pose.jpg`: only the header's arrangement makes each option act on its own
field. The Dart wrapper (`lib/src/io/native_holistic_landmarker.dart`) now writes the
header's order on every platform. It previously copied the Python order on
Linux, Windows and the official macOS runtime, and CI could not see it because
the references came from the same Python.
`tool/generate_landmark_tasks_reference.py` now rearranges Python's slots into
the header's order before creating tasks, and asserts the ctypes still use the
old order so a fixed wheel fails loudly. Its non-default case (hand 0.99) now
drops both hands, as the option promises.

### UP-006: Holistic mask smoothing retains dimensions across IMAGE requests

**Status:** reproduced in official MediaPipe 1.0.0 Mac Python API. Unresolved
upstream; worked around in the reference generator and in how the tests use the
public wrapper.

Reusing a Holistic task with segmentation masks enabled across differently sized
images, including a rotated image, fails even in IMAGE mode:

```text
SegmentationSmoothingCalculator
RET_CHECK ... current_mat->rows == previous_mat->rows (1000 vs. 667)
```

The failed graph also reports the same error during `close()`, which can mask the
original processing exception.

`tool/generate_landmark_tasks_reference.py` now builds a fresh task for every
IMAGE request and keeps one task only for a VIDEO sequence, which is what IMAGE
mode promises and what `test/landmark_tasks_test.dart` does on the Dart side. The
checked-in reference was regenerated from scratch after that change; the earlier
file, written from incorrectly packed raw fixtures, is gone. A caller that reuses
one Holistic task with masks enabled across differently sized images still hits
this; VIDEO mask processing needs a documented size policy.

### UP-008: Stateful Interactive Segmenter GPU stroke shader fails on macOS

**Status:** prior repository validation, documented for official 1.0.0 and 1.0.1
Mac runtimes; not newly rerun during the desktop work.
Re-tested October 7, 2026 with Google's 1.1.0rc20260925 macOS wheel: the
shader still fails to compile (`version '330' is not supported`,
`heatmap_from_strokes_calculator_gl.cc:561`).

`HeatmapFromStrokesCalculatorGl` requests GLSL 330 in a macOS OpenGL 2.1 context.
Shader compilation fails. CPU is validated; GPU is rejected with this specific
reason. This does not imply that Metal or all MediaPipe GPU tasks are broken.

Evidence and prior validation artifacts are documented in
`packages/mediapipe-task-vision/tool/INTERACTIVE_SEGMENTER.md` and
`packages/mediapipe-task-vision/tool/validations/2026-09-12-interactive-segmenter/`
(in git history at `3e217ac`).
Morning commit `72711df` corrected attribution to a single runtime version.

### UP-009: Image Segmenter creation crashes on a null display-names locale

**Status:** reproduced through this repository's Dart bindings against the pinned
1.0.0 runtime. Worked around locally; not reported upstream.

`MpImageSegmenterOptions.display_names_locale` is a `const char*` that
`MpImageSegmenterCreate` dereferences unconditionally, so passing null segfaults
inside task creation rather than returning a status:

```text
si_signo=Segmentation fault: 11(11), si_code=SEGV_ACCERR(2), si_addr=0x0
MpImageSegmenterCreate
```

The equivalent classifier field tolerates null: `classifier_options_c.py` sets
`display_names_locale = None` when no locale is requested, and that path works.
Google's own Image Segmenter bindings never exercise the null case because
`MpImageSegmenterOptionsC.from_c_options` always passes `ctypes.c_char_p(b'')`.

`lib/src/io/native_image_segmenter.dart` therefore always passes a string, using an
empty one when the caller requests no locale. Review this field for each new
task rather than assuming null is accepted.

### UP-010: Segmentation tasks reject a region of interest

**Status:** confirmed through the official 1.0.0 Python API; expected behavior
rather than a defect, recorded because the C API accepts the argument.

`MpImageSegmenterSegmentImage` and the legacy Interactive Segmenter both take
`MpImageProcessingOptions`, which carries a rectangle, but supplying one fails:

```text
ValueError: This task doesn't support region-of-interest.
```

Rotation is accepted. The Dart wrappers therefore expose `rotationDegrees` only,
instead of offering a parameter the task rejects at run time.

### UP-013: Holistic IMAGE results depend on earlier IMAGE calls

**Status:** reproduced September 23 in Google's official 1.0.0 macOS Python
wheel and the iOS 1.0.1 SDK. Unresolved upstream; the tests work around it.

One Holistic task given the same image four times in IMAGE mode returned
landmarks 0.033 to 0.050 apart from its first result (Python wheel), and 0.0078
apart on the iOS simulator. A fresh task's first call is exactly repeatable.
IMAGE mode should not carry state between calls. `sdk_landmark_tasks_test.dart`
and the web API probe compare only fresh tasks' first results for Holistic.

### UP-015: Pose GPU treats rotated input differently from Pose CPU

**Status:** reproduced September 23 in Google's official 1.0.0 macOS wheel and
on an iPhone 15 Pro with the 1.0.1 iOS SDK. Unresolved upstream; recorded, not
worked around.

Upright, Pose CPU and GPU agree to 0.005 (wheel, Metal) and 0.014 (iPhone).
Given the same image turned a quarter with `rotation_degrees = 90`, they differ
by 0.16 (wheel) and 0.22 (iPhone, against the CPU reference). CPU output is also
not a plain rotation of the upright result. Hand, Gesture and Holistic show
neither effect. The SDK tests require the rotated reference on the CPU only for
Pose and record the GPU value.

### UP-017: Image Segmenter stretches the upright mask over a rotated input

**Status:** reproduced September 23 in Google's official 1.0.0 macOS Python
wheel and the iOS 1.0.1 SDK. Unresolved upstream; the package returns what
Google's runtimes return.

Given a rotated input and `rotation_degrees`, Image Segmenter segments the
upright image, then resizes that upright mask to the input's width and height
instead of turning it back. For `landmark-ex1.jpg` turned a quarter turn, the
returned category mask agrees with the upright mask turned back on 37% of
pixels, and with the upright mask resized to the input's shape on 99% (90°:
0.990, 270°: 0.992, 180°: 0.987, which also comes back unflipped). Pose and
Holistic masks do turn back correctly (mean difference 0.003 to 0.007), as
do Interactive Segmenter Legacy's (97% of pixels at 90° and 270°).
`sdk_segmenter_test.dart` checks rotated inputs against the resized upright
mask, and the desktop fixture records the same bytes as Google's wheel.

### UP-023: Android Image Segmenter GPU aborts on a PowerVR GPU

**Status:** observed September 23 on a physical Galaxy A12 (PowerVR Rogue
GE8320, Android 12), and on September 29 on a Pixel 10 (Android 16) and a
Pixel 11 (Android 17), whose Tensor chips also carry PowerVR GPUs, all in
Firebase Test Lab with Google's tasks-vision 1.0.0. Worked around by refusing
the delegate, since the abort happens inside Google's native code, which the
plugin cannot catch; since October 14, 2026 on every Android GPU, after
Google's C library aborted the same way on a Pixel 3
([UP-061](#up-061-image-segmenters-gpu-mask-aborts-the-app-when-it-is-read-on-a-pixel-3)).
Since October 6, 2026, Android runs Google's per-family C library. On October
7 a Galaxy A12 ran every task on it in Test Lab, but the package refuses this
delegate there before Google's task exists, so the abort itself has not been
re-tested.

Image Segmenter on the GPU delegate terminates the app while Google's Java
task converts the result: `PacketGetter` aborts with `image_frame.cc:298]
Invalid format: UNKNOWN`. The same test passed on CPU on that phone (every
category cell agreed with Google's reference), and on GPU on a Pixel 8a (Mali)
and a Galaxy S24 (Adreno) the task ran. On the Pixels every other task's GPU
suite passed first.

The Android adapter now reads the GPU's OpenGL ES renderer and vendor once
(`TaskPlatform.gpu`). On a PowerVR GPU, `queryImageSegmenterCapabilities()`
reports GPU unsupported with this issue as the reason, and the plugin refuses to
create a GPU Image Segmenter there, so `ImageSegmenter.create` throws a
`RuntimeUnavailableException` with this reason instead of the app aborting.
Other tasks, and other GPUs, keep the GPU delegate.

### UP-025: Windows task closes wait for Google's usage-logging upload

**Status:** observed September 24 with Google's official 1.0.0 Windows wheel
on GitHub's windows-2025 runners, first as two 30 s test timeouts in a
[desktop run](https://github.com/hugocornellier/mediapipe_flutter/actions/runs/36004929701).
CI blocked the endpoint on Windows until October 13, 2026; it now lets the
uploads through and gives each test 180 s. The package cannot turn the
logging off. Android phones wait the same way with the 1.2.0 nightly of
October 18 (Test Lab, October 20): a close took 60 to 500 ms on the Pixel
8a, Galaxy S24, Galaxy A10 and Galaxy A12, once 1.9 s on the A12, and 1.0 to
2.5 s on the Pixel 3 (Android 9). On the agenda for October 20, 2026, but
not reached; still to raise with Google.

Google's native library carries a Clearcut usage-logging client: its embedded
source paths include
`mediapipe/tasks/cc/core/logging/google_internal/clearcut_logging_client.cc`,
and the C header describes `MpBaseOptions.ca_bundle_path` as the "CA bundle to
use for usage logging". It posts to `https://play.googleapis.com/log` through
WinINet, and a task's close waits for the upload.

With the endpoint reachable, the median close took 62 ms in
[one probe run](https://github.com/hugocornellier/mediapipe_flutter/actions/runs/36019400724)
and 125 ms in
[another](https://github.com/hugocornellier/mediapipe_flutter/actions/runs/36022472695),
where `curl` to the same endpoint took 0.12 to 0.14 s. Some closes waited 20
to 34 s: 13 of 648 in the first run, and 1 of 485 in the second, where one
more had not returned when its test run ended. Stack dumps taken 5 and 15 s
into those waits show the closing thread blocked in `WaitForSingleObjectEx`
under `MpHandLandmarkerClose` (or the task's own close), a library thread
blocked in `WININET!HttpSendRequestA`, and almost no CPU use: under 0.1 s per
thread between the two dumps. The endpoint also answered some uploads with
HTTP 503. With `play.googleapis.com` resolved to an unroutable address
([run](https://github.com/hugocornellier/mediapipe_flutter/actions/runs/36023936830)),
486 closes took a median of 9 ms and at most 34 ms, and no test timed out.

The factory that creates the client has no switch; it falls back to a no-op
client only when its log store cannot be created. Google's Python wrapper
fills the same logging fields and offers no opt-out. On Windows, `dispose()`
lasts as long as the upload; blocking the host removes both the upload and
the wait. The Linux 1.0.1 library contains the same uploader (over libcurl,
with `ca_bundle_path` as its CA file); no slow close has been seen on Linux.

Google's per-family macOS libraries wait the same way, and so do its October
8 iOS libraries, the first iOS builds with the uploader.
- **macOS, October 9:** with the reply held for 40 s by a local receiver, each
  close took 40,011 to 40,014 ms. Refused, closes took 2 to 9 ms; with the
  host unroutable, about 4.1 s.
- **iOS Simulator:** with the host unroutable, closes took about 4 s.
- **CI:** a slow reply fits the lone 30 s test timeouts in the macOS runtime
  job (#59, #79, #82 and #84). That job's tests now get 180 s each, more than
  the upload request's own 60 s timeout, and so do the desktop and family
  jobs' tests on every host.
- **macOS, October 23:** the "Every package" job of the macOS workflow ran
  `make test_only`, whose suites still had the default 30 s. In
  [one run](https://github.com/hugocornellier/mediapipe_flutter/actions/runs/39978702710)
  the audio test that opens and then closes 64 streams timed out after 30 s
  and finished 8 s later; the eleven runs before it took 2 to 3 s. The
  library logged `Network error: 503 for url: https://play.googleapis.com/log`
  22 s into the wait, and the job beside it saw the same answers for the next
  twenty minutes. The Makefile's `dart test` lines now pass `--timeout 180s`
  as the family workflow does.

### UP-026: Holistic cannot open its face blendshapes model on a desktop or iPhone GPU

**Status:** observed September 25 through Google's own Python API with the
official 1.0.0 macOS wheel (on a hosted macos-15 runner and on macOS 27) and
the official 1.0.1 Linux wheel (OpenGL ES on Mesa, renderer renamed as in the
desktop GPU job). On October 7, 2026 the same Metal check failed with Google's
pre-release 1.1.0 iOS library on an iPhone 15 Pro (iOS 27.0), now at
`inference_calculator_metal.cc:286`. On a Pixel 8a's Mali GPU the same
subgraph fails through Google's per-family Android library (Test Lab,
October 7, 2026): `Batch size mismatch, expected 1 but got 1 values with
divergent batch sizes: id:1 shape:[52, 1, 1, 1]`. Holistic stays on CPU on
desktop, iOS and Android.
Re-tested October 7, 2026 with Google's 1.1.0rc20260925 macOS wheel: the
same check fails on Metal (`inference_calculator_metal.cc:286`).

`HolisticLandmarker` on the GPU delegate fails when its graph opens, in the
inference calculator of the face blendshapes subgraph, whether or not
blendshapes or the segmentation mask are requested. On Metal:
`inference_calculator_metal.cc:284 TFLGpuDelegateBindMetalBufferToTensor(...)
== true (0 vs. 1)`. On Linux the same node fails to open while reporting a
tensor of shape `[52, 1, 1, 1]`, the blendshapes model's. Face Landmarker's own
blendshapes run on these GPUs, so the gap is Holistic's graph.

### UP-027: Linux Image Embedder aborts on OpenGL ES

**Status:** observed September 25 with the official 1.0.1 Linux wheel on a
hosted ubuntu-24.04 runner (Mesa, renderer renamed as in the desktop GPU job),
through Google's own Python API. The package keeps the Linux embedder on CPU;
it runs on Metal on macOS.

`ImageEmbedder` with the GPU delegate aborts the process (SIGABRT) during its
first embeds, with glibc reporting `corrupted size vs. prev_size while
consolidating`. Google's Python also declares the embedding result with the
wrong layout and overruns it on every embed (the text package's
`tool/official_embedding_layout.py`; the vision image generator now corrects
it too), but correcting that layout in the probe changed nothing: the GPU path
still aborts. The classifier, segmenter and detector run on the same GPU.

### UP-028: Pose segmentation masks fail on Metal

**Status:** observed September 25 through Google's own Python API with the
official 1.0.0 macOS wheel, on a hosted macos-15 runner and on macOS 27. The
package refuses the combination with an explanation instead of failing on the
first frame; Pose landmarks run on Metal.
Re-tested October 7, 2026 with Google's 1.1.0rc20260925 macOS wheel: the
same failure, now after the shader compiler reports `version '330' is not
supported`.

With `output_segmentation_masks` on, `PoseLandmarker` fails on its first
frame in `TensorsToSegmentationCalculator`:
`tensors_to_segmentation_converter_metal.cc:223 upsample_program_ Problem
initializing the program`. Without masks the task runs on Metal. On Linux's
OpenGL ES path the masks work, and so does Image Segmenter's own mask
conversion on Metal.

### UP-029: Linux stateful Interactive Segmenter aborts on OpenGL ES

**Status:** observed September 25 with the official 1.0.1 Linux wheel on a
hosted ubuntu-24.04 runner (Mesa, renderer renamed), through Google's own
Python API. The package keeps the task on CPU on Linux, as on macOS (UP-008).

Segmenting a positive stroke with the GPU delegate aborts the process with
glibc's `corrupted size vs. prev_size while consolidating`. The browser task
runs the same model on WebGL 2.

### UP-030: Linux Pose masks on OpenGL ES are 8-bit RGBA images

**Status:** observed September 25 with the official 1.0.1 Linux wheel on a
hosted ubuntu-24.04 runner (Mesa, renderer renamed), through Google's own
Python API. The package refuses Pose masks on Linux GPU with the reason;
landmarks run on the GPU, and masks on the CPU.

With `output_segmentation_masks` on the GPU delegate, `PoseLandmarker` returns
each mask as a 4-channel 8-bit image (`numpy_view()` gives values 0 to 255,
with the confidence in the red channel), where its CPU path returns one
float32 confidence per pixel (VEC32F1). Image Segmenter's GPU masks on the
same runtime stay float32.

### UP-031: iOS SDK GPU tasks abort on the iOS Simulator

**Status:** observed September 23 (Hand Landmarker) and September 29 (Face
Landmarker, a gallery still image) with Google's 1.0.1 iOS XCFrameworks on an
iOS 26.4 simulator on Apple silicon, locally and on hosted macos runners.
Worked around by refusing the delegate on the simulator, since the abort
happens inside Google's native code, which the package cannot catch. Google's
per-family 1.1.0 iOS library aborts the same way on the simulator
(`DrishtiMetalHelper.cc:212`, `kCVReturnError` -6660, October 6, 2026), so the
refusal stays.

A GPU task aborts the app (SIGABRT) the first time it processes an image: a
failed absl check in `-[DrishtiMetalHelper copyCVMetalTextureWithGpuBuffer:plane:]`,
called from `ImageToTensorMetalConverter::Convert`. That preprocessing is
shared by every vision task. The CPU delegate works on the simulator, and the
GPU delegate passes every SDK suite on a physical iPhone 15 Pro.

`TaskPlatform.simulator` is true in a simulator process (the simulator sets
`SIMULATOR_UDID` in every app's environment). There the vision capability
queries offer the CPU only, with this issue as the GPU reason, and every task
refuses a GPU `create` with an error instead of the app aborting.

### UP-032: macOS GPU tasks keep every frame until they close

**Status:** observed October 1 with Google's official 1.0.0 macOS engine and
the source-built 1.0.0 Face Detector, on an M4 Max (macOS 27), through the
package and through a plain C harness. The code is unchanged on MediaPipe's
master. Worked around in the package by reopening the task. Issue
[#5510](https://github.com/google-ai-edge/mediapipe/issues/5510) has an
[M1 Mac report of the same abort](https://github.com/google-ai-edge/mediapipe/issues/5510#issuecomment-2417746088)
"after running for a while", and Python users report the same growth on
macOS: [#5652](https://github.com/google-ai-edge/mediapipe/issues/5652) and
[#5626](https://github.com/google-ai-edge/mediapipe/issues/5626).
Re-tested October 7, 2026 with Google's per-family 1.1.0 macOS library:
without the reopen, Face Detector on the GPU still grows about 1.2 MB a
frame (1.3 GB after 1,100 frames), so the workaround stays.

On the GPU delegate, `ImageCloneCalculator` converts each CPU input image for
the GPU. `CreateCVPixelBufferForImageFrame` (`mediapipe/objc/util.cc`) copies
it into a new 32BGRA pixel buffer, from no pool, and
`GpuBufferStorageCvPixelBuffer::GetTexture` wraps that buffer in a texture from
the OpenGL context's `CVOpenGLTextureCache`. On macOS (`gl_context_nsgl.cc`)
the cache is flushed only in `DestroyContext`, so it keeps every frame's buffer
until the task closes: 1.2 MB a frame from a 640x480 camera for Face Detector,
Pose Landmarker, Image Classifier and Object Detector, and 2.4 MB for Hand
Landmarker. The CPU delegate stays flat. A camera demo fills memory at its
frame rate until `CVPixelBufferCreate` fails with `kCVReturnAllocationFailed`,
and MediaPipe's check aborts the app (`gpu_buffer_storage_cv_pixel_buffer.cc`:
`Error creating pixel buffer: -6662`). The gallery's Face Detector closed this
way after nine minutes on the camera.

Closing the task releases every buffer. On macOS GPU, each vision worker counts
the bytes it sends to the GPU and, after 1 GiB (about 30 seconds of a 640x480
camera at 30 fps; 512 MiB for Face Detector, below), closes its native task and
opens an identical one
(`lib/src/io/gpu_frame_budget.dart`). It holds the model in memory from the
first open, because the app may delete the model file once the task exists. On an M4 Max reopening takes about 20 ms
for Face Detector and 250 to 800 ms for the engine's tasks, so one frame in
each interval waits that long, and a video task resumes tracking from a new
detection. Hand Landmarker keeps two buffers a frame, so it holds up to 2 GiB
before reopening. `test/face_detector_gpu_memory_test.dart` runs 2,000 camera
frames on the GPU with the engine loaded too and the model file deleted, and
fails if memory grows past the budget or a result is lost across a reopen.

On GitHub's macOS runner, a virtual Mac, the 1.1.0 libraries' Face Detector
kept about 2.5 MB a frame on the GPU, twice an M4 Max's (October 7, 2026, run
37663838178). Its GPU inference now runs on LiteRT, which logs "Failed to
create Metal Residency Set" there. Every reopen still freed the frames, but
after 1 GiB of input the test grew by 1.54 GB, so Face Detector reopens after
512 MiB; on the M4 it then peaks at 293 MB instead of 788 MB.

### UP-034: Browser text runtime omits Proofreader and Summarizer

**Status:** confirmed against the pinned `@mediapipe/tasks-text` 1.0.1 bundle
and its `text.d.ts` on September 30, 2026, and again on October 2. The web
package keeps the two tasks unsupported, with the capability queries citing
this entry, and serves EmbeddingGemma through `TextEmbedder`, whose browser
`embed(text, formatOptions)` takes Google's format context.

Google's Android SDK, iOS SDK and desktop wheel C APIs expose
`TextProofreader` and `TextSummarizer`, including streaming callbacks. The
browser bundle exports only `TextClassifier`, `TextEmbedder` and
`LanguageDetector`, and `text.d.ts` declares no other task. The
1.1.0-rc.20260929 nightly adds a JavaScript `TextSummarizer` that calls
`createTextSummarizer` on the WASM module, but its declarations do not list
it and its WASM, the same size as 1.0.1's, shows no sign of it; neither
version has a Proofreader. Recheck when a stable release declares either
task.

### UP-036: iOS Summarizer generations drift from Google's wheel late in long summaries

**Status:** measured October 2, 2026 on the arm64 iOS simulator against
Google's macOS arm64 1.0.1 wheel, the same release on the same architecture.
Google's behavior, not a defect in this repo; recorded so the mobile suite's
tolerance has its evidence. No upstream issue filed. On October 6, 2026,
Google's per-family 1.1.0 text library on the simulator matched the macOS
1.1.0 wheel on all 10 Summarizer cases; the first request's stream still
parted from its completed text after 94 characters.

With the same model, inputs and request order, the simulator matched the
wheel byte for byte on all 9 Proofreader cases and on all 17 EmbeddingGemma
embeddings (maximum error 0.0, quantized bytes identical), and on 8 of the 10
Summarizer cases. The two longest summaries part from the wheel after 167 of
221 and 110 of 238 characters, the sentences rephrased from that point on;
on the first request of a fresh task the streamed text also parted from the
completed text, after 94 characters. Greedy decoding picks a different word
once floating-point noise between the two builds flips a near-tie, which
longer generations give more chances to.

Google's own Python API shows the same on its x86_64 1.0.0 wheels: on the
Linux and Windows CI runners, `TextSummarizer.summarize_async` streamed a
different text than `summarize` returned for the same input and task (the
macOS arm64 wheels agree on every case). The reference generators therefore
record both paths and note whether they agreed (`stream_matches_result`),
and the desktop tests compare the package's completed and streamed results
each with Google's own for that path. The text also depends on the requests
before it on the same task: on the Windows 1.0.0 wheel, the same summary
streamed as the first request of a fresh task ended "if no critical bugs
remain" where the reference, recorded after a completed request, ended "if
no bugs remain". The tests that compare exactly replay the generator's
request order; the lifecycle tests, which do not, require the text to follow
Google's for 80 characters or in full when shorter.

`gallery/integration_test/sdk_modern_text_test.dart` therefore requires
every generated text to follow Google's for at least 80 characters, or in
full when Google's is shorter, which identical prompts, tokenization, mode
and decoding produce and anything else does not, and logs the exact-match
count. The earliest parting measured is the 94 characters above.

On the x86_64 Android emulator in CI, against Google's Linux x86_64 1.0.0
wheel, the Proofreader matched exactly in both runs measured (9 of 9), while
the Summarizer matched 8 of 10 cases in one run and 7 of 10 in the next, on
different cases each time; one key-points summary shared only its first 21
characters with the wheel's. Google's x86_64 build is not reproducible there
even run to run, so the mobile suite requires each summary to have its
mode's shape (key points bulleted, a TL;DR in prose) and a majority of the
cases to match Google's exactly, which a wrong prompt, mode or token budget
could not produce; the arm64 emulator (10 of 10) and the iOS simulator (8 of
10) clear that easily.

On the Test Lab phones (run 37048770818 and, for the A12, 37052916414),
against the macOS arm64 1.0.0 wheel's references: the Galaxy S24 (Adreno,
API 34) and Pixel 8a (Mali, API 35) reproduced Google's wheel bit for bit,
all 17 EmbeddingGemma embeddings at error 0.0, 9 of 9 Proofreader and 10 of
10 Summarizer cases exact. The Galaxy A12 (Cortex-A53 cores, API 31) had an
EmbeddingGemma error of 0.0061 and matched 5 of 10 summaries exactly, every
one within the prefix rule, and wrote a different, correct TL;DR for the
lifecycle test's case, so that test now applies the prefix rule too. The
generations are therefore reproducible across the arm64 phones whose cores
compute as the Mac's do, and drift on older cores as on x86_64.

EmbeddingGemma's vectors show the same build dependence: the arm64 emulator
and the iOS simulator reproduce Google's wheel of their release bit for bit,
while Google's x86_64 Android 1.0.0 build on the x86_64 emulator differs
from its Linux x86_64 1.0.0 wheel by up to 0.008 per value (0.0723 against
0.0685 for the third value of the plain "A cat is sleeping on the sofa."
embedding in one run, 0.0073 at most in the next). The mobile suite bounds
each value at 0.02, requires a cosine similarity of at least 0.995 with
Google's vector, and logs the largest difference it saw. The desktop suites keep byte-for-byte comparison, since each host
compares with the wheel its own runtime library comes from.

On October 7, 2026, on macOS arm64, Google's Summarizer was not reproducible
from run to run on four of the benchmark's cases (`tool/task_benchmarks`): the
long input, a paragraph repeated twelve times, in key-points mode at token
budgets 0, 1024, 4096 and 8192. Across the checked-in reference and two fresh
runs of the generator on the 1.1.0rc20260925 wheel, each of the four came out
as three or four different summaries, of 519 to 584 characters. In two runs of
the benchmark on the per-family 1.1.0 library, all four differed from the
reference both times, three of them with a different text the second time, on
the completed path as well as the streamed one. Every version shared exactly
its first 98 characters (the first bullet, then "Renovations" followed by
"start" or "begin"). The other 93 cases, including every key-point summary of
the short input and every TL;DR, were identical in every run of both. On
GitHub's macOS arm64 runner, an M1 (run 37649760586), every case the benchmark
checked before the first of the four matched the reference exactly, all twelve
TL;DR cases among them, and so did that case's completed summary; its streamed
summary did not. The benchmark therefore requires those four to follow
Google's text for 80 characters and compares everything else exactly.

Google's per-family 1.1.0 libraries and its 1.1.0rc20260925 wheel are
different builds, and on most hosts their summaries part late. On GitHub's
macOS runner (run 37649760586) the text package's `tldr-meeting` summary
followed the wheel's for 167 characters, then said the release was scheduled
for Tuesday where the wheel said the new settings screen would be delayed,
and `keypoints-unicode` parted after 112; a Pixel 8a parted at the same 167
characters, while an M4 Max matched every case. Every Summarizer comparison in
the text package's suite and its fresh-app validation therefore follows
Google's text for 80 characters, or in full when shorter, and counts the exact
matches (22 of 31 texts on the runner).

### UP-037: The audio stream's flushed tail is stamped with a sentinel, not a time

**Status:** observed October 4, 2026 with Google's 1.0.0 macOS wheel and core's
1.0.0 macOS library, the 1.0.1 iOS SDK on the simulator and the 1.0.0 Android
SDK on the API 31 emulator; worked around in `mediapipe_audio`. No upstream
issue filed.
Unchanged with Google's per-family 1.1.0 libraries: on October 7, 2026 the
audio suite's check of Google's raw sentinel passed on macOS.

In AUDIO_STREAM mode, closing an Audio Classifier flushes the audio short of a
window, and its result is stamped 9223372036854775 ms on every platform:
`Timestamp::Max()` divided by 1000. The calculator's flush mode defaults to
`ENTIRE_TAIL_AT_TIMESTAMP_MAX`
(`mediapipe/calculators/tensor/audio_to_tensor_calculator.proto`), which the
audio graph never changes, so the tail's tensor leaves at `Timestamp::Max()`
and each SDK divides that time by 1000. The value says only that the result is
the tail; a caller drawing a timeline cannot use it, and a browser could not
hold it, since it is above 2^53. Clips mode stamps the same padded chunk with
where it starts.

`mediapipe_audio` delivers the tail with where its audio starts, the first
block's timestamp plus the windows before it, which is what clips mode
reports for the same chunk. Its tests still assert that the raw value from
Google is the sentinel, through a hook at the adapter, as the proof that the
result came from Google's flush.

### UP-038: The C audio stream callback carries no user data and no message

**Status:** read in Google's v1.0.0 source and observed October 4, 2026 with
core's 1.0.0 macOS library; worked around in `mediapipe_audio`. No upstream
issue filed.
Unchanged in 1.1.0: the 1.1.0rc20260925 wheel declares the same callback
type (checked October 7, 2026).

`MpAudioClassifierOptions.result_callback` is
`void (*)(MpStatus status, MpAudioClassifierResult* result)`
(`mediapipe/tasks/c/audio/audio_classifier/audio_classifier.h`). Unlike the
text streams' callbacks, it passes no user data, so a caller with several
streams cannot tell them apart; `mediapipe_audio`'s bridge compiles 64
callbacks, one per open stream, and refuses a 65th. A failure arrives as a
status with a null result and no message (`audio_classifier.cc`), although in
practice Google's task runner hands the callback only successful packets, and
a graph failure surfaces instead from the next `MpAudioClassifierClassifyAsync`
("Graph has errors: ...") and from `MpAudioClassifierClose`, both with
Google's message. The callback runs on MediaPipe's own threads, never the
caller's, and not always the same one: a C harness saw three thread changes in
five callbacks, each call finished before the next began, and none after the
close returned, even when every call took 300 ms.

### UP-041: Two defects in the C Audio Classifier

**Status:** read in Google's v1.0.0 source; not observed to fail. No upstream
issue filed.

- The stream callback allocates its one result with
  `std::make_unique<MpClassificationResult>()` and frees it through
  `MpAudioClassifierCloseResult`, which uses `delete[]`
  (`mediapipe/tasks/c/audio/audio_classifier/audio_classifier.cc`): `new`
  freed with `delete[]` is undefined behavior, harmless with the allocators
  in use but a finding for AddressSanitizer.
- `MpAudioClassifierClose` deletes the task only when its close succeeds, so a
  close that fails, as after a graph failure, leaks the task, and nothing can
  close it again.

### UP-042: Per-family macOS and simulator libraries have no header room for a rename

**Status:** fixed in Google's 1.1.1 development build of October 9, 2026:
every macOS dylib and iOS slice leaves 15 to 28 KB, so the hook bundles
Google's files as is and the workaround below is gone. Observed October 6,
2026 in Google's pre-release per-family C libraries (1.1.0 development builds
of October 5); reported to Google on October 8, 2026.

Dart (`dart test`, `dart run`) and Flutter give every bundled library a new,
longer install name. Google's macOS libraries leave 40 (audio), 48 (text) and
80 (vision) bytes between their load commands and their first section, and
the iOS simulator slices 40 to 88, so the rename fails: "install_name_tool:
changing install names or rpaths can't be redone ... larger updated load
commands do not fit (the program must be relinked, and you may need to use
-headerpad or -headerpad_max_install_names)". The iOS device slices carry
about 12 KB, so they are evidently linked with
`-headerpad_max_install_names`; the fix is to link the macOS and simulator
builds the same way.

Until the 1.1.1 build, `bundleFamilyRuntime` named the system frameworks
without their `Versions/A/` directory, which macOS resolves to the same files,
and signed the copy again, freeing 144 to 168 bytes (room after: vision 248,
text 208, audio 184, retrieval 240). Google's delivery of October 8, 2026
(decision and retrieval) was linked the same way: 72 to 80 bytes on macOS,
and 32 on the simulator slices, less than any slice before. That covered the
install names Dart and Flutter write for ordinary project paths. On iOS the
frameworks keep Google's file names, so Flutter's new install name has the
same length as Google's.

### UP-043: Per-family libraries each define the same Objective-C classes

**Status:** observed October 6, 2026 in Google's pre-release per-family C
libraries. Harmless while all three come from one build; not worked around.
Not yet reported to Google.

On macOS the text and audio libraries each define 34 Objective-C classes that
the vision library defines too (`GTMSessionFetcher` and its helpers, the
`GIPLog*` and `GTMLog*` logging classes, `IonNetworkHelper`,
`MPPMetalSharedResources`), so a process with all three logs 68 "Class ... is
implemented in both" warnings and uses whichever copy loaded first. On iOS
the slices shared `MPPMetalSharedResources` and miniaudio's
`ma_ios_notification_handler`; since the 1.1.1 build added the usage-logging
client on iOS, they also share `GTMSessionFetcher`, the `GIPLog*` and
`GTMLog*` classes and `IonNetworkHelper`, as on macOS. Libraries from different releases in one app
could then run one family's code against another family's class layout.

### UP-044: Apple GPU tasks abort on a three-channel image instead of failing

**Status:** observed October 6, 2026 with Google's pre-release per-family
iOS library on the arm64 simulator (Object Detector and Pose Landmarker on
GPU), and reproduced the same day through Google's own Python API with the
official 1.0.0 macOS wheel and the 1.1.0rc20260925 nightly (Object Detector on
Metal: RGBA runs, SRGB aborts). 1.0.0's message is only "unsupported
ImageFrame format: 1"; 1.1.0 names the cause but still aborts. Worked around
in `mediapipe_vision`. No upstream issue filed.

On October 7, 2026 it also stopped the gallery on a physical iPhone 15 Pro
(iOS 27.0): `MpImageCreateFromFile` decodes a JPEG to three-channel `SRGB` on
iOS, but to `SRGBA` on macOS, so `VisionImage.fromFile` on the GPU aborted
only on the phone. On a device the message dies with the process; the crash
report shows `abort()` in `MediaPipeTasksVisionC`, called from line 154.

Given an `SRGB` image on the GPU, the graph stops the process:
`gpu_buffer_storage_cv_pixel_buffer.cc:154] Check failed: status_or_buffer is
OK (INVALID_ARGUMENT: Unsupported ImageFrame format: SRGB. MacOS/iOS GPU
input requires an alpha channel.)`. The status is already an error; a
`CHECK` turns it into an abort no caller can catch. The vision package adds
opaque alpha before every GPU task, to raw pixels and to the 8-bit gray or
RGB images Google's decoder reads from files.

### UP-045: Per-family Windows libraries export TensorFlow Lite and LiteRT

**Status:** observed October 6, 2026 in Google's pre-release per-family C
libraries. Not a failure; recorded for Google. No upstream issue filed.

Besides their C API (100 `Mp*` functions in vision, 31 in text, 18 in
audio), the Windows DLLs export 151 `TfLite*` functions and 44 (vision,
audio) or 256 (text) `LiteRt*` ones, on x64 and arm64 alike. The macOS,
Linux and iOS builds export only the C API. An app that loads another
TensorFlow Lite next to one of them can bind the wrong copy.

### UP-046: Face Detector's GPU needs a LiteRT plugin the Linux and Android libraries do not ship

**Status:** observed October 7, 2026 with Google's pre-release per-family
libraries on GitHub's Linux runner (Mesa OpenGL ES) and on a Pixel 8a (Mali)
in Firebase Test Lab, and through Google's own Python API with its
1.1.0rc20260925 Linux wheel. Worked around in `mediapipe_vision` by
withdrawing the delegate. Not yet reported to Google.

Creating Face Detector on the GPU fails: `inference_runner_litert.cc: Failed
to compile model. Some ops are not accelerated. Add kLiteRtHwAcceleratorCpu
to the compilation accelerator set to allow using the CPU to run those.` Since
1.1.0 its GPU inference runs on LiteRT, and no other task's does (on macOS
every other task still logs TensorFlow Lite's Metal delegate). On Linux and
Android, LiteRT loads its GPU backend from a plugin: the logs show it looking
for `libLiteRtGpuAccelerator.so`, `libLiteRtClGlAccelerator.so` (Android),
`libLiteRtOpenClAccelerator.so`, `libLiteRtVulkanAccelerator.so` and
`libLiteRtWebGpuAccelerator.so`, then "GPU accelerator could not be loaded and
registered". None of them ships with the libraries or with the Linux wheel,
whose only native file is `mediapipe/tasks/c/libmediapipe.so`. Apple's builds
register their Metal accelerator statically.

`queryFaceDetectorCapabilities()` reports the GPU unsupported on Linux and
Android with this issue as the reason, and `FaceDetector.create` refuses it
with `RuntimeUnavailableException` before Google's graph exists. Face
Landmarker and the other tasks keep the GPU there.

### UP-047: OpenGL ES GPU category masks come back as float32

**Status:** observed October 7, 2026 with Google's pre-release per-family
Android library on a Pixel 8a (Mali) in Firebase Test Lab, and explained from
MediaPipe's source. Handled in `mediapipe_vision`. Not yet reported to Google.

On the CPU, and on Apple's GPUs, Image Segmenter's category mask holds one
uint8 class per pixel. On OpenGL ES GPUs (Android and Linux),
`segmentation_postprocessor_gl.cc` renders it into a float texture holding
each class divided by 255, or a one-class model's 0 and 255 as 0.0 and 1.0
(`kGrayFloat32`, or `kGrayHalf16` where the GPU cannot render float32, which
reads back as an unknown format). The C API's result converter hands that
image back unchanged, so `MpImageDataUint8` fails on it. The package reads a
one-channel float32 mask and rounds each value times 255 back to the class;
the Pixel 8a, the Galaxy S24 and Linux's Mesa GPU then match Google's GPU
references. A truncating read of the same float explains UP-024.

### UP-048: The Windows library runs the stateful Interactive Segmenter about 100 times slower than Linux

**Status:** observed October 7, 2026 on GitHub's `windows-2025` runner with
Google's pre-release per-family Windows library (1.1.0-dev.20261005), in
the desktop validation of pull request #78. The package keeps the task off
Windows. Not yet reported to Google.

Google's `mediapipe_tasks_vision.dll` exports `MpInteractiveSegmenterCreate`,
`SetImage`, `Segment` and `Close`, the same 100 `Mp*` functions as the macOS
and Linux libraries, and its masks agree with the macOS wheel's within 0.045
(`file-cat` 0.0449, `raw-dog` 0.0358), so the task runs. It runs slowly: the
package's pixel-exact suite, 14 cases that the `ubuntu-24.04` runner finishes
in 5 seconds, got through two in its 2-minute budget on Windows, and a
decoder-only `segment` after the image was set took about 26 seconds. LiteRT
logged "XNNPACK CPU accelerator registered" on both runners, so the
accelerator is present; the int8 kernels it reaches on Windows are not the
Linux ones. Google's Windows Python wheel of the same release
(`mediapipe-nightly` 1.1.0rc20260925, `libmediapipe.dll`) exports only the
Legacy task, as the 1.0.1 wheel did, which is where the package's earlier "no
stroke API on Windows" came from. With no Windows oracle and a stroke that
takes longer than the editor's whole session elsewhere, the package does not
offer the task on Windows.

### UP-049: The browser Decision Maker fails every evaluation without a hardware WebGPU adapter

**Status:** observed October 8, 2026 with Google's `@mediapipe/tasks-decision`
1.1.0 and the Laya model in Chromium, with and without this package: on a Mac
(Metal) and on GitHub's `ubuntu-24.04` runner (SwiftShader). Worked around:
the package runs Decision Maker in browsers on the GPU delegate only, and its
capability query offers it only where the browser has a hardware WebGPU
adapter, by Google's own rule. Not yet reported to Google.

With `baseOptions.delegate: 'CPU'` the task is created (backend type -1), but
`evaluateBoolean`, `evaluateChoice`, `evaluateScore` and their batch forms all
throw `TypeError: e(...).then is not a function`: the bundle's request
wrapper calls `.then` on the WASM call's result, and on the CPU path that call
returns its answer synchronously. The ES module and classic WASM builds fail
alike. With `delegate: 'GPU'`, as Google's own web demo defaults, every
evaluation succeeds on a hardware WebGPU adapter and matches Google's native
library to about 2e-7 (Laya, "The customer wants a refund.": 0.7654307
against the wheel's 0.7654309). Without one the GPU delegate fails the same
way: the bundle skips WebGPU when no adapter is found or the adapter is a
fallback or software one (`/swiftshader|llvmpipe|software|lavapipe/`), and
the task then takes its CPU path. Hosted Linux runners have only SwiftShader,
so CI there checks that the gallery refuses the task with this reason.

### UP-050: Universal Embedder refuses the text-only EmbeddingGemma 2 model

**Status:** observed October 8, 2026 with Google's mediapipe 1.1.0 wheel on
macOS arm64 and its per-family retrieval library. Worked around: the
retrieval package pins only the two EmbeddingGemma 2 models with a vision
encoder. Not yet reported to Google.

Google's Universal Embedder guide lists three EmbeddingGemma 2 models,
including the text-only 270M one (`embeddinggemma-2-text-270m.litertlm`, the
model Decision Maker's bi-encoder backend runs). `UniversalEmbedder.create`
refuses it at creation, before any input:

```
ERROR: [third_party/odml/litert_lm/runtime/core/embedding_engine_impl.cc:503]
└ ERROR: [third_party/odml/litert_lm/runtime/core/embedding_engine_impl.cc:293]
└ ERROR: [third_party/odml/litert_lm/runtime/executor/model_signature_utils.cc:283]
└ ERROR: [third_party/odml/litert_lm/runtime/executor/model_signature_utils.cc:168]
└ tf_lite_vision_encoder not found in the model.
```

The engine looks the vision encoder up unconditionally, so a text-only
deployment has to download the 388 MB text and vision model instead of the
165 MB text one. The text and vision 440M and the full 740M models load and
answer.

### UP-051: The browser Universal Embedder reads modelAssetPath as a file, and a second Wasm object needs the loader again

**Status:** observed October 8, 2026 with Google's `@mediapipe/tasks-retrieval`
1.1.0 in Chromium. Worked around in the retrieval package's worker. Not yet
reported to Google.

Two differences from Google's other browser tasks:

- `UniversalEmbedder.createFromOptions` with `baseOptions.modelAssetPath` set
  to a URL fails with "Model asset path does not exist or is not a readable
  file": the task hands the string to its engine as a file path instead of
  fetching it, as `DecisionMaker` and the text tasks do. The worker fetches
  the URL itself and passes `response.body.getReader()` as
  `modelAssetBuffer`, which the type declarations allow.
- `SemanticRetriever.createFromComponents` requires a text chunker, and
  `DefaultTextChunker.create(wasmFileset)` fails with "ModuleFactory not set"
  once an embedder exists in the same worker: every Wasm-backed object
  imports the loader script and reads the `ModuleFactory` global it sets,
  which the bundle clears after use, and a second `import()` of the same URL
  comes from the module cache without running the script again. The worker
  gives the chunker the embedder's own module (`createFromModule`) when it
  can find it, and otherwise imports a fresh copy of the loader.

### UP-052: The browser Universal Embedder runs only on a hardware WebGPU adapter

**Status:** observed October 8, 2026 with Google's `@mediapipe/tasks-retrieval`
1.1.0 in Chromium on GitHub's `ubuntu-24.04` runner (SwiftShader) and on a
Mac (Metal). Worked around: the retrieval package offers browsers only the
GPU delegate, and only where the browser has a hardware WebGPU adapter, by
Google's own rule; elsewhere `create` refuses with the capability query's
reason. Not yet reported to Google.

`UniversalEmbedder.createFromOptions` takes no delegate. When
`baseOptions.device` is unset it creates a WebGPU device for itself
(`navigator.gpu.requestAdapter({powerPreference: 'high-performance'})`, then
`requestDevice`), and throws "No appropriate WebGPU adapter found." or
"WebGPU is not supported on this platform." when it cannot. There is no CPU
path, unlike the vision, text and audio browser tasks. On a hardware adapter
(Metal on a Mac) both retrieval tasks answer as Google's native library does.
Decision Maker's browser runtime has the same requirement for a different
reason (UP-049).

### UP-053: The per-family decision library fails every evaluation with the text-only EmbeddingGemma 2 model

**Status:** fixed in Google's 1.2.0 nightly of October 18, 2026: on macOS
arm64 its decision library answers every case of
`packages/mediapipe-task-decision/test/fixtures/embedding_gemma_2_text_vision_reference.json`
with the text-only model as Google's wheel does, within 1e-6 (run with
`MEDIAPIPE_DECISION_EG2_TEXT_MODEL`, October 19). The other targets run it
in CI. The package's workaround (the capability query and `create`
refusing the model on the per-family library, and the gallery's Hungry
Fish playing on the text and vision model there) is gone. On the October
20, 2026 agenda as fixed; whether the call reached it is not recorded.

Observed October 9, 2026 with Google's per-family decision library of
October 8, 2026 (`libmediapipe_tasks_decision.dylib`, macOS arm64); the
gallery's Hungry Fish, which played on this model, showed an error on the
arm64 iOS Simulator too. Google's 1.1.0 wheel library of October 6
(`libmediapipe.dylib`, macOS arm64) runs the same model through the same
calls.

Google's Decision Maker guide lists EmbeddingGemma 2 as a bi-encoder
backend, and its web demo starts with the text-only 270M model
(`embeddinggemma-2-text-270m.litertlm`, 165 MB). On the per-family library
`MpDecisionMakerCreate` accepts it, but every evaluation
(`MpDecisionMakerEvaluateBoolean`, the choice and score calls and their
batch forms) returns status 13 with `EG2 embedder invocation failed.` The
wheel's library answers the same calls with the same model (0.4516 for "The
customer wants a refund." on the gallery's refund text). With the text and
vision 440M model (`embeddinggemma-2-text-vision-440m.litertlm`, 388 MB),
whose text encoder is the same, the per-family library answers every case
as the wheel does, within 1e-6
(`packages/mediapipe-task-decision/test/fixtures/embedding_gemma_2_text_vision_reference.json`,
run with `MEDIAPIPE_DECISION_EG2_MODEL`): 0.45160728693008423 on both for
that question. The two libraries drive the model differently: the
per-family one carries messages for a signature runner of its own (`EG2
embedder signature runner unavailable`, `Failed to allocate EG2 embedder
tensors`), the wheel's goes through LiteRT-LM's `EmbeddingEngine`. The
text-only model has the `tf_lite_text_encoder` and `tf_lite_embedder`
signatures; the 440M one adds `tf_lite_vision_encoder` and
`tf_lite_vision_adapter`. Universal Embedder refuses the same model at
creation (UP-050).

### UP-054: In WebKit, the browser runtime embeds every input as zeros with EmbeddingGemma 2

**Status:** observed October 12, 2026 with `@mediapipe/tasks-decision` and
`@mediapipe/tasks-retrieval` 1.1.0 in Playwright's WebKit 26.6 on macOS 27,
Apple M4 Max, on its hardware WebGPU adapter (vendor `apple`, architecture
`apple`), and again on GitHub's `macos-26` runner (macOS 26.6.2, a virtual
Apple M1) with the runtime from jsDelivr (CI run 38291903608). Playwright's
Chromium 153 on the same Mac and GPU answers correctly. Safari itself was
not tried. Worked around: the decision and
retrieval capability queries read the browser's engine
(`TaskPlatform.browserEngine`, from the user agent) and report both
EmbeddingGemma 2 Decision Maker models and both retrieval tasks unsupported
in WebKit; the gallery shows Hungry Fish, Universal Embedder and Semantic
Retriever as cards there, and Decision Maker runs Laya. On the October 20,
2026 agenda; whether the call reached it is not recorded. Retested
October 21, 2026 with the 1.2.0 nightlies of October 18 (the pin) and
October 21, Google's npm tarballs verified and served locally, in the same Playwright WebKit 26.6 on the same Mac: the
Universal Embedder still returns 768 zeros for every text with the 388 MB
model, while Chromium 153 returns unit vectors (cosine 0.88 between the dog
and puppy sentences, 0.63 between the dog and the stock market). The
Decision Maker's symptom changed: with that model on the GPU it no longer
ties at 0.333 but gives "eat" 0.9996 to 0.9999 for all three Hungry Fish
sentences, predator included (Chromium: flee 0.73, eat 0.40, ignore 0.73),
so the first-option tie-break is gone and the answers are still wrong. Laya
gives the same probabilities in both engines to six decimals, as before.

Google's own JavaScript, run in the page with no package code, shows it.
`UniversalEmbedder.embedText` returns a 768-value vector of zeros (norm 0)
for every text with both pinned retrieval models
(`embeddinggemma-2-text-vision-440m.litertlm`, 388 MB, and
`embeddinggemma-2-740m.litertlm`, 485 MB); in Chromium the same calls return
unit vectors (norm 0.9999997 for "A dog chases a ball across the park.").
Decision Maker with either EmbeddingGemma 2 model
(`embeddinggemma-2-text-270m.litertlm`, 165 MB, and the 388 MB one) scores
every option of every question 0.333 of 3 in WebKit, so the first option
wins every tie: Hungry Fish chased every predator. Chromium answers the
game's three sentences right with clear margins (flee 0.860 for "Predator
nearby: a pufferfish, bigger than you."). Laya (`laya_s256.task`) gives the
same probabilities in both browsers, so the WebGPU device itself works; the
fault is on the EmbeddingGemma 2 path. Semantic Retriever then finds no
document at a minimum similarity of 0, and Universal Embedder's cosine
similarity is NaN.

The two adapters differ in `subgroup-size-control` (Chromium only),
`float16-renderable` and `float32-renderable` (WebKit only), and
`maxBufferSize` and `maxStorageBufferBindingSize` (2 GB in WebKit, 4 GB in
Chromium). Both offer `shader-f16` and `subgroups`.

On GitHub's `macos-15` runners, which CI uses, WebKit has no
`navigator.gpu` at all, so CI never reaches this path; on `macos-26` WebKit
gets the Apple adapter and reproduces it.
`gallery/tool/browser/test_gallery_journey.mjs --browser=webkit` on a Mac
with Apple silicon, or on `macos-26`, reaches it and expects the cards.

### UP-055: The browser Decision Maker aborts while it creates the task with GLiNER2.5-Decide

**Status:** observed October 12, 2026 with `@mediapipe/tasks-decision` 1.1.0
in Playwright's Chromium 153 and WebKit 26.6 on macOS 27, Apple M4 Max, on
the GPU delegate. Worked around: `queryDecisionMakerCapabilities(model)`
reports both GLiNER2.5-Decide models unsupported in browsers, and the
gallery's Decision Maker page offers neither there. On the October 20, 2026
agenda; whether the call reached it is not recorded.

`DecisionMaker.createFromOptions` with `gliner_s256.task` or
`gliner_s512.task` rejects with `RuntimeError: Aborted(). Build with
-sASSERTIONS for more info.`, with or without `maxNumTokens` (256 or 4096).
Laya and EmbeddingGemma 2 load from the same page.

### UP-056: The browser Decision Maker ignores normalizePrior and scoringMode

**Status:** read from `decision_bundle.mjs` of `@mediapipe/tasks-decision`
1.1.0 on October 12, 2026, and confirmed by results that do not change with
either. Documented on the options; not worked around. On the October 20,
2026 agenda; whether the call reached it is not recorded.

`evaluateBoolean` passes the condition, threshold and temperature to the
Wasm engine, and `evaluateChoice` the criteria, instructions, context and
temperature; neither passes `normalizePrior`, and `evaluateChoice` does not
pass `scoringMode`. Google's C API takes both. In browsers, Laya therefore
reads "No fish nearby." as flee (0.478, explore 0.324) on the question that
Google's 1.1.0 wheel, with the prior normalized, answers explore.

### UP-057: The 1.1.1 macOS library gives different Metal results from Google's 1.1.0 wheel

**Status:** observed October 12, 2026 with Google's 1.1.1 development build of
October 9 (the per-family vision library for macOS arm64) on an Apple M4 Max
(macOS 27) and on GitHub's `macos-15` runners, and in Google's
`mediapipe-nightly` 1.1.1rc20261013 wheel on October 13. Worked around: the
vision package withdraws the macOS GPU for every task until Google says
whether the new output is intended. Raised with Google on October 13, which is
investigating.

On the CPU, every task matches the 1.1.0 release candidate wheel
(`mediapipe-nightly` 1.1.0rc20260925) exactly, as the October 5 build did. On
Metal, the October 5 build matched the wheel's Metal output on the same Mac
exactly too, but the 1.1.1 build differs for every vision task the package
runs there, by these largest amounts on the M4 Max
(`tool/test_macos_references.py`, and the package suites against the
checked-in Metal references):

- Image Classifier: the top score falls from 0.804 to 0.584 on one input, and
  on three others the top class changes from "cloak", which the wheel picks on
  the CPU and on Metal, to "abaya".
- Image Embedder: values move by up to 0.20.
- Image Segmenter: confidence masks move by up to 0.13.
- Pose Landmarker: landmarks move by up to 0.094 of the image width (0.168 on
  GitHub's runner).
- Object Detector: on two images it finds one object fewer or one more, on
  the group shot its first detection is a different object, and boxes move by
  up to 24 pixels.
- Face Detector: boxes move by up to 12 pixels and scores by up to 0.017.
- Hand Landmarker and Gesture Recognizer: handedness scores move by up to
  0.065.
- Face Landmarker: landmarks move by up to 0.007.

Compared with the CPU, the change goes both ways: one face box and one
classifier score lie closer to the CPU than the wheel's Metal output does, and
the classifier's "abaya" is not among the CPU's top three. Google's final
1.1.0 wheel gives the same Metal output as the release candidate. GitHub's
runner and the M4 Max differ the same way, so the change comes from the
library, not the machine.

Google's first 1.1.1 Python wheel, `mediapipe-nightly` 1.1.1rc20261013,
gives the October 9 build's output exactly, on Metal and on the CPU, in the
36 Image Classifier and Image Embedder cases compared (the other tasks were
not run), so the change is in 1.1.1 itself. The likely cause is Google's
`d59afd232c` of October 9, "Fix GPU interactive segmentation on macOS",
which changed the macOS GPU input path every vision task shares; that is
read from the diff, not bisected.

To restore the GPU once Google confirms the new output, or once the
packages decide to follow it: pin a 1.1.1 wheel in
`packages/mediapipe-core/lib/src/native_assets/reference_wheels.dart` and
regenerate the references, drop `_macosGpuGap` from
`packages/mediapipe-task-vision/lib/src/capabilities.dart`, mark the macOS GPU
cells of `tool/coverage/matrix.json` required again, and bring back the Metal
steps this withdrawal removed from `.github/workflows/main.yaml` and
`packages/mediapipe-task-vision/tool/test_macos_references.py`. iPhones keep
the GPU: every iOS suite passed on an iPhone 15 Pro with the 1.1.1 build, GPU
required.

### UP-058: Universal Embedder's audio embeddings change from call to call

**Status:** observed October 12, 2026 on an Apple M4 Max (macOS 27) with the
full EmbeddingGemma 2 model (`embeddinggemma-2-740m.litertlm`), through
Google's Python API from the `mediapipe` 1.1.0 wheel and through the
package on Google's 1.1.1 retrieval library alike, both on the CPU. Text and
image embeddings repeat exactly. Worked around in the tests only: they
compare audio within 0.01. Still seen on October 19 with the 1.2.0 build of
October 18, whose audio embeddings also moved from 1.1.0's by up to 0.017 per
value, as Google's own `mediapipe-nightly` 1.2.0rc20261018 wheel's did, so
the audio reference now comes from that wheel. Raised with Google on
October 20, 2026; Google said it would look into it.

The same samples give a different audio embedding from one call to the
next, and from one process to the next: Google's Python embeds the audio
package's 4.3 s `speech_16000_hz_mono.wav` with values up to 0.006 apart on
two calls in a row, and two separate runs of
`tool/generate_reference.py --audio` disagree by up to 0.005 per value and
0.004 in a retrieval score. One 15,600-sample (0.975 s) clip usually
repeats exactly, but not always: the result also moves with the audio
embedded before it. A Semantic Retriever's scores for audio records vary
the same way.

### UP-059: With the Flutter host environment, the usage log drops the OS

**Status:** fixed in Google's 1.2.0 nightly of October 18, 2026. Observed
October 20 by capturing each upload with that build: macOS records the OS
as Mac, Linux as Linux, Windows as Windows, the iOS Simulator and an iPhone
15 Pro (iOS 27) as iOS, and the Android emulator as Android, each with the
Flutter environment and the host_version as given; browsers record the OS
with the Flutter Web environment, from a worker too. Found October 13, 2026
with the October 9 build on macOS, Linux, Windows and the iOS Simulator, and
raised with Google that day. One task still records nothing: the Semantic
Retriever's uploads carry no OS, environment or host_version
([UP-063](#up-063-semantic-retrievers-usage-uploads-carry-no-os-host-environment-or-host-version)).

Google's libraries record the host environment and OS from
`MpBaseOptions.host_environment` and `host_system` in each usage upload.
Before the fix, with `host_system` set to `MP_HOST_SYSTEM_MAC`, a Language
Detector's upload recorded the OS as Mac when the environment was
`MP_HOST_ENVIRONMENT_PYTHON`, and as unknown when it was
`MP_HOST_ENVIRONMENT_FLUTTER`, with or without `host_version`, `app_id` and
`app_version`; on the iOS Simulator, Python's value recorded iOS, and
Flutter's unknown. The environment arrived as Flutter, and `host_version` as
given.

### UP-060: Decision Maker and Universal Embedder reserve memory for their whole token budget

**Status:** measured October 13, 2026 on an Apple M4 Max (macOS 27) with
Google's 1.1.1 decision library of October 9, on the CPU, reading the
process's footprint (what iOS limits) with `footprint`; seen on an iPhone 15
Pro (iOS 27.0) with the October 9 iOS library. To raise with Google on the
October 15 call. Worked around: `DecisionMakerOptions.maxNumTokens` defaults
to 0, which Google's header defines as the model's own budget, as
`UniversalEmbedderOptions.maxInputLength` already did, and both options'
documentation gives the cost of a larger one. Each package's
`memory_budget_test.dart` fails on macOS when a pinned model adds more than
1.5 GB at the defaults.

Google's Decision Maker reserves memory for `MpDecisionMakerOptions.max_num_tokens`
when it is created, whatever the length of each input, and the reservation
grows much faster than the budget. With the text and vision EmbeddingGemma 2
(388 MB), the footprint after creation is about 0.6 GB at 512 tokens (the
model's default, which 0 selects), 1 GB at 2048 and 6.7 GB at 4096, the
default of Google's Python `DecisionMakerOptions`. Laya takes about 0.7 GB
at 4096.
Closing the task returns the memory. On the iPhone 15 Pro, iOS stops the
gallery at its 3.4 GB limit seconds after the Hungry Fish page creates
EmbeddingGemma 2's Decision Maker at 4096 tokens (`exceeded mem limit:
ActiveHard 3376 MB`), in debug and release builds alike.

The budget also caps the input without saying so: a text of about 1,500
words gets one answer at 4096 tokens, and another, identical at 0 and 512, at
the shorter budgets, with no error. The 17 reference cases give the same
answers at 0, 512 and 4096.

Google's Universal Embedder does the same with
`MpUniversalEmbedderOptions.max_input_length`: after creating it and embedding
one sentence, the footprint grows by about 0.4 GB with the text and vision
EmbeddingGemma 2 and 0.2 GB with the audio one at 0, the model's default, and
by 6.0 and 5.9 GB at 4096.

For Google: whether reserving the whole budget up front is intended, and
whether the tasks can report an input they cut off.

### UP-061: Image Segmenter's GPU mask aborts the app when it is read, on a Pixel 3

**Status:** observed October 14, 2026 on Firebase Test Lab's Pixel 3
(`blueline`, Android 9, API 28, Adreno 630) with Google's 1.1.1 vision
library of October 9. Every other vision task passed there on the CPU and
the GPU. Worked around since October 14: the package offers Image
Segmenter's GPU on no Android device, since the abort spans Google's two
Android APIs and at least two GPU families, and a GPU nobody has tried may
be next.

It is the failure of
[UP-023](#up-023-android-image-segmenter-gpu-aborts-on-a-powervr-gpu) in
Google's other Android API: there Google's Java SDK (tasks-vision 1.0.0)
aborted the app on PowerVR GPUs while converting the same task's GPU result
(`image_frame.cc:298] Invalid format: UNKNOWN`). So it lies in MediaPipe's
shared GPU path, not in the C API.

After the segmenter's CPU cases, its GPU case ends the process:

```text
F DEBUG   : Abort message: 'F0000 ... image_frame.cc:109] Check failed: ImageFormat::UNKNOWN != format_ (0 vs. 0)'
    #11 pc ... base.apk (MpImageGetWidth+8)
```

The package reads a result mask's size with `MpImageGetWidth`. In Google's
C API (`mediapipe/tasks/c/vision/core/image.cc`) every accessor,
`MpImageGetFormat` included, starts with `GetImageFrameSharedPtr`, which
turns the GPU mask into an `ImageFrame`; that conversion reaches the check.
So a caller cannot ask for the format first and refuse an unreadable mask:
the first accessor aborts.

For Google: return an error status instead of aborting, or a mask the CPU
view can read, on this GPU.

### UP-062: The iOS libraries call required-reason APIs and ship no privacy manifest

**Status:** read October 14, 2026 from Google's 1.1.1 iOS libraries of
October 9, in a release archive of the gallery with every family
(`flutter build ipa`). Not reported upstream yet. Worked around in the
gallery, whose `ios/Runner/PrivacyInfo.xcprivacy` declares the APIs, and
[privacy_and_licenses.md](doc/privacy_and_licenses.md#app-store-privacy-manifest)
tells apps to do the same. No upload to App Store Connect has tested it:
the gallery's `com.example` bundle ID cannot be uploaded.

App Store Connect refuses an iOS upload whose code calls an API on Apple's
required-reason list without a declared reason (ITMS-91053), in the app or
in a framework it embeds. Each of Google's framework zips holds the binary and
its Info.plist only, and the binaries import:

| Library | Imports | Apple's category |
| --- | --- | --- |
| Every family's (vision, text, audio, decision, retrieval) | `stat`, `fstat` | File timestamp |
| Every family's | `NSUserDefaults` | User defaults |
| Retrieval's | `statfs`, `fstatfs` | Disk space |

From the binaries' strings, the user defaults probably belong to the
GTMSessionFetcher that the usage logging uploads through, and the disk space
calls to the SQLite that the retrieval library embeds. The libraries are
otherwise ready for the store: arm64 only, iOS 15.0 in the binaries as in
the Info.plists Flutter writes, and signed by the build.

A manifest from Google would not reach apps through the packages yet:
Flutter 3.47.5 wraps each native-assets library in a framework of its own
making, with no way to add a `PrivacyInfo.xcprivacy`, so apps declare the
APIs in their own manifest.

For Google: a privacy manifest for each iOS library, with the reasons for
these APIs and the data its usage logging collects, which apps must also
describe in their App Privacy answers; or the reasons, for the packages to
document.

### UP-063: Semantic Retriever's usage uploads carry no OS, host environment or host version

**Status:** observed October 20, 2026 with Google's 1.2.0 nightly of
October 18 by capturing each usage upload: on an Apple M4 Max (macOS 27),
on GitHub's Linux and Windows runners (CI run 39398538766) and on the iOS
Simulator. Google's own Python API does the same (`mediapipe-nightly`
1.1.0rc20260925 on the same Mac), so it is the C API's design, not the
packages'. The browser retriever records all three. Raised with Google on
October 20, 2026; Google said it would look into it. No workaround:
`MpSemanticRetrieverOptions` has no `base_options`, so the packages have
nowhere to put the fields.

Every other task's options struct in the October 18 headers (20 of them,
from `MpFaceDetectorOptions` to `MpDecisionMakerOptions` and
`MpUniversalEmbedderOptions`) holds a `struct MpBaseOptions base_options`,
with the model path, the delegate and the `host_environment`, `host_system`
and `host_version` that the usage uploads record. `MpSemanticRetrieverOptions`
holds the database path, the embedding dimension, the embedder pointers
(`MpUniversalEmbedderPtr`, `MpTextEmbedderPtr`, `MpImageEmbedderPtr`) and the
chunking settings, nothing else. The retriever is built on an embedder whose
options carry the host fields, yet its own events (task 29: session start,
invocation report, session end) go out with platform 0, host environment 0
(UNKNOWN) and an empty host_version, in the same upload body as the
embedder's complete events (task 28), and Google accepts both (HTTP 200). On
the Android emulator the retriever's close opens its own connection with a
body about 115 bytes smaller than the other tasks', which fits a body
without the host fields.

For Google: let the retriever take base options, or copy its embedder's host
fields into its own usage logger.

### UP-064: The umbrella headers have no license text, and the Audio Classifier header misstates it

**Status:** read October 20, 2026 from Google's
`mediapipe_tasks_c_20261018.zip` (the 1.2.0 nightly of October 18), whose
headers are byte-identical to `packages/mediapipe-core/native/include`.
Raised with Google on October 20, 2026; Google said it would look into it
and fix it. Cosmetic; nothing to work around.

The five generated umbrella headers, `mediapipe_tasks_<family>.h`
("Generated file. DO NOT EDIT."), open with no license comment, while the
task headers carry the Apache 2.0 one. Of those, only
`audio/audio_classifier/audio_classifier.h` says "You may not obtain a copy
of the License at" on its fifth line; the other 44 say "You may obtain a
copy of the License at", as the Apache text does.

## History

Findings about runtimes the packages no longer use: the vision source builds,
Google's Android Java SDK, its iOS SDK and core's iOS adapter, and Google's
1.0.x releases. They stay as the record of what was found and why some checks
exist.

### UP-001: KleidiAI SME wrappers can execute non-streaming SVE on Apple M4

**Status:** crash reproduced; isolated compiler-flag workaround verified and
committed in the vision package's source build, `tool/build_native.py` (in git
history at `6c940cf`; the per-family libraries replaced the source build). macOS CPU support stays declared unavailable because of the
separate numerical failures in UP-004.

**Affected observation:** macOS arm64, Apple M4 Max, pinned MediaPipe v1.0.0
source revision `6d31f1ebc3284db74d211d62bdc4f0a0c29ea120`, combined CPU/Metal
runtime. EfficientDet-Lite0 Object Detector and EfficientNet-Lite0 Image
Classifier reach the fault. Face Detector and Face Landmarker smokes do not.

Object Detector reproduces outside Dart using
`packages/mediapipe-task-vision/tool/object_detector_probe.cc`, in git history
at `9383185`. The fault was:

```text
SIGILL
kai_run_lhs_pack_f32p2vlx1_f32_sme+0x20
xnn_compute_inline_packed_qp8gemm
```

Disassembly of the original wrapper has `addvl sp, sp, #-2` at `+0x20`, before
streaming mode is entered. Clang also emits SVE vector operations in this C
wrapper. The working official 1.0.0 Mac wheel's wrapper has scalar code in that
position. The evidence supports automatic vectorization into non-streaming SVE
as the cause; the assembly kernel itself enters streaming mode.

The candidate adds this Bazel flag without modifying upstream source:

```text
--per_file_copt=external/KleidiAI/.*[.]c@-fno-vectorize,-fno-slp-vectorize
```

The candidate wrapper no longer has the trapping prologue. Native Object
Detector CPU inference succeeds, Face CPU/Metal smokes pass, and Image Classifier
and Embedder CPU tests execute without crashing. This does **not** imply that all
their reference comparisons pass.

Candidate SHA-256:
`7133bfed77463171f1af4792d3cbcb8dbbb2bb6d5a37e7aa204be856292b649e`.
Original SHA-256:
`dbc5ea41d10c334e2f7adc9a746f109334d0826abbd9cedd5d03360c8b4f6238`.

The candidate is now the pinned macOS `vision-v1.0.0-1` runtime digest. That
release is still unpublished, so the hook serves it only from a local build.

Local candidate, manifest, smokes and archive:
`build/ci-tmp/vision-no-vectorize/`.
Original library and manifest backup:
`build/ci-tmp/vision-before-sme-fix/`.
The candidate was copied into the package's ignored `build/native/tasks/` for
Dart validation. The compiler flag and runtime pin are committed; the library
itself is not published.

Inspect with:

```sh
xcrun llvm-objdump --disassemble-symbols=_kai_run_lhs_pack_f32p2vlx1_f32_sme build/ci-tmp/vision-no-vectorize/libmediapipe.dylib
```

The upstream genrule retains install name `@rpath/libmediapipe_source.dylib`.
For an isolated native executable, provide that filename as a copy of the
candidate and set `DYLD_LIBRARY_PATH` to its directory. This loader detail is
separate from the illegal instruction.

### UP-002: XNNPACK's explicit disable branches select the enabled configuration

**Status:** confirmed by inspection of the dependency used by the pinned build.

In `external/XNNPACK/BUILD.bazel`, the `arm_sme_enabled`, `arm_sme2_enabled` and
`kleidiai_enabled` aliases map their `..._explicit_false` branches to
`..._explicit_true`. Consequently these proposed workarounds do not disable the
kernels in this revision:

```text
--define=xnn_enable_arm_sme=false
--define=xnn_enable_arm_sme2=false
--define=xnn_enable_kleidiai=false
```

There is also an apparent `XNN_ENABLE_SRM_SME` typo in the false branch of
`build_defs.bzl`. Do not assume that adding these defines fixes UP-001.

The dependency was cached under
`build/ci-tmp/bazel/d8fd7dbf830ea5ade71924b0dfe6131d/external/XNNPACK/`,
deleted on October 14, 2026 with the source builds' Bazel cache; XNNPACK's
public source holds the same files.
See also the earlier investigation in
`packages/mediapipe-task-vision/tool/OBJECT_DETECTOR.md`, in git history at
`9383185`; its statement that no compiler workaround has been found is now
superseded by UP-001.

### UP-003: MediaPipe 1.0.0 float mask accessor aborts for padded rows

**Status:** reproduced through the official 1.0.0 Mac Python API. The scalar
fallback is implemented in both the reference generator and the Dart mask helper,
and Linux/Windows CI exercises it through the Pose and Holistic mask cases.
**Fixed in 1.1.0.** Re-tested October 7, 2026 with Google's per-family
1.1.0 macOS library: the padded 667x1000 Image Segmenter masks copy
correctly through `MpImageDataFloat32` and match Google's references, so the
package and the reference generator dropped the fallback.

Positive Pose Landmarker results with noncontiguous float32 masks can terminate
the process when `mask.numpy_view()` calls `MpImageDataFloat32`:

```text
Check failed: 1 == ChannelSize() (1 vs. 4)
mediapipe::ImageFrame::CopyToBuffer()
GenerateContiguousDataArray
GetCachedContiguousDataAttr
MpImageDataFloat32
```

The contiguous-copy path selects the uint8 ImageFrame overload for float data.
Contiguous masks avoid this path. Odd widths and rotated inputs expose it;
testing only widths whose rows require no padding misses the defect.

The reference generator used `numpy_view()` only for contiguous
masks and official `mask[y, x]` scalar reads otherwise. The Dart helper
`copyVisionConfidenceMask` mirrored that strategy with `MpImageIsContiguous` and
`MpImageGetValueFloat32`, copying every value into owned Dart storage. Both
hosts compared every sampled mask value against the official output.

Reproduce with the official 1.0.0 environment and:

```sh
build/ci-tmp/mediapipe-reference/bin/python -u -B packages/mediapipe-task-vision/tool/generate_landmark_tasks_reference.py
```

On 1.0.0, run the generator with `mask.numpy_view().copy()` (as it is now)
to see the abort.

### UP-004: Mac source CPU outputs differ from the same-version official wheel

**Status:** unresolved compatibility finding, **not yet proven to be an upstream
bug**. Do not silently relax tolerances or regenerate goldens through our own
native wrappers.

After the UP-001 candidate fixes the crash:

```sh
cd packages/mediapipe-task-vision
dart test test/image_tasks_test.dart --reporter expanded --concurrency=1
dart test test/object_detector_test.dart --reporter expanded --concurrency=1
```

Image tasks pass 26 tests and fail four ROI comparisons at the existing `1e-5`
float tolerance / exact quantized-byte comparison. Example classifier ROI score:
official `0.16696061193943024`, source `0.16767385601997375`. A quantized ROI
embedding differs at index 7: official `255`, source `254`.

Object Detector passes 30 tests and fails five CPU comparisons, including
repeated cases in recovery/video tests. Example tie score on `landmark-ex1.jpg`:
official `0.450329452753067`, source `0.4504084587097168`. Metal still passes its
existing reference comparisons. Several raw, unrotated CPU cases also pass.

Image decoding was checked independently: source C API and official Python
produce exactly identical RGBA pixels for `landmark-ex1.jpg` and
`iris-detection-ex2.jpg` (zero differing bytes), with a local probe script that
was not kept.

The four landmark tasks are gated the same way:
`landmarkTaskCapabilitiesForPlatform` covers Linux x64 and Windows x64 only, and
`test/landmark_tasks_test.dart` skips its comparisons on macOS rather than
comparing a different binary's arithmetic.

Preprocessing, compiler behavior, and OpenCV build differences remain candidates
to investigate; none has been established as the cause. These observations do
not affect the passing Linux/Windows official-wheel CI baseline.

### UP-007: Official 1.0.1 Mac detector graphs can abort opening a CPU graph

**Status:** external upstream report, checked 2026-09-16; not reproduced anew in
this session. [MediaPipe issue #6356](https://github.com/google-ai-edge/mediapipe/issues/6356)
is open.

The report concerns macOS arm64, Apple M5, Python 3.14.5, MediaPipe 1.0.1. Face
Detector, Face Landmarker, Hand Landmarker and Pose Landmarker abort opening
graphs with `TensorsToDetectionsCalculator`; its Metal helper requests an
unavailable graph service in a CPU graph. Classifier and Embedder succeed in the
reported tests. Avoid generalizing this report to every task or OS.

This is why the desktop vision baseline pins working 1.0.0 wheels rather than
automatically upgrading everything to 1.0.1. Modern stateful Interactive Segmenter
and modern text tasks have their own runtime requirements.

### UP-011: Combined iOS simulator CPU runtime has reference differences beyond face tasks

**Status:** measured compatibility finding on 2026-09-16; not established as an
upstream bug. Face Detector and Face Landmarker remain validated. Other source
task support declarations have not been expanded.

The combined arm64 simulator build exports all 114 declared C functions. Running
all eleven vision task families in a fresh Flutter app with temporary support
overrides in an isolated package copy yields **107 passed, 56 failed, 49 GPU
skips**. The failing comparisons retain the desktop suite's existing tolerances
and exact mask-byte checks. Simulator runtime: iOS 26.4, host: Apple M4 Max.

The first attempt exited during Object Detector CPU inference. Disassembly
showed the same non-streaming SVE prologue described in UP-001. Applying the
existing scoped KleidiAI compiler flag to the iOS build removes those instructions
and allows the complete suite to run without that exit.

The rebuilt simulator library SHA-256 is
`a4fea1f2abddb6d656b043b5471a09a64df1308475422da9800c8f880cd2aa9e`.
Examples: Object Detector score `0.4504084587097168` versus the official
`0.450329452753067`; classifier ROI score `0.16767385601997375` versus
`0.16696061193943024`; normalized quantized ROI embedding byte 7 is `254`
versus `255`. These match UP-004's macOS observations. Hand/Gesture/Pose/Holistic
coordinates or confidences exceed `1e-5` in some cases; confidence mask hashes
also differ. Category-mask cases and many other cases pass.

Reproduction, from the vision package with a booted simulator and downloaded
models, using the source-build tools in git history at `6c940cf`:

```sh
python3 -B tool/build_ios_simulator.py
python3 -B tool/test_ios_consumer.py --experimental-all-tasks
```

Local evidence: root `build/ci-tmp/ios-consumer-yb2gy4pg/`. The report marks
the capability overrides explicitly; they never modify the consumer package's
real support declarations. Confidence-mask hash comparisons are intentionally
stricter than numerical float comparisons; a failed hash alone does not establish
the size or practical significance of a difference.

An additional lead: the pinned official Mac 1.0.0 wheel embeds a build-information
string naming OpenCV 4.13.0, whereas the local builders pin OpenCV 4.12.0. That
embedded string also describes a Linux x64 build, so it is not sufficient evidence
of the Mac binary's actual build configuration or of a cause for these differences.

### UP-012: Android combined runtime needs C API export isolation

Observed September 16 with pinned MediaPipe v1.0.0, NDK 28.2.13676358,
OpenCV 4.12.0's Android SDK, and an arm64 Android 16 emulator using 16 KB pages.
The first combined runtime built and exported all 114 C APIs, but the native
face probe crashed before entering inference. The Android crash backtrace ends
at `/system/lib64/libprotobuf-cpp-lite.so (_GLOBAL__I_000101+60)` during linker
constructor initialization. The runtime exported internal C++/protobuf symbols;
this behavior is consistent with symbol interposition against system protobuf.

Upstream's task BUILD applies its existing C API version script only to Linux.
A recorded Android-specific BUILD selection now applies that same map to the
combined library. `-z start-stop-visibility=hidden` also hides linker-generated
`__start_pb_defaults` and `__stop_pb_defaults` symbols. The resulting runtime
exports only the public C APIs and its version definition. Both native CPU face
IMAGE probes then pass on the same emulator. No task source/graph code changed.

The GPU-disabled Android build also fails compiling `gl_texture_buffer_pool.cc`
because it includes `gl_context.h` while `GlVersion` and `GlTextureInfo` are
hidden. The candidate uses Android's normal GL-enabled configuration and
selects CPU delegates for validation. Its probes initialize EGL even with CPU
delegates; a functioning GL context is therefore part of the tested environment.
GPU inference remains unvalidated.

Reproduce with `tool/build_android.py` in the vision package (in git history at
`6c940cf`), then the probe `tool/test_android_native.py` and the Android guide
`tool/ANDROID.md`, both in git history at `9383185`.
The passing runtime has SHA-256
`1a01c7ebef93f0a113d8c9714c72b0012198d7dfc7dcff12207db67667de3658`.
Build and smoke receipts are under `tool/validations/2026-09-16-android-native/`
in git history at `3e217ac`.
These probes check loading, ABI and result counts, not Flutter packaging,
numerical reference parity or physical-device performance. Android package
support remains undeclared. This issue has not been filed upstream.

Since October 6, 2026, Android runs Google's per-family libraries instead of
this source build. They export only the `Mp*` C API plus the linker's
`__start_pb_defaults` and `__stop_pb_defaults` markers, and pass the gallery's
Android suites on the arm64 emulator (API 31, CPU).

### UP-014: iOS Holistic rejects rotated images

**Status:** observed September 23 with Google's 1.0.1 iOS XCFrameworks.
Worked around in the iOS adapter. Since October 6, 2026, iOS runs Google's per-family C library through the
same C API path as macOS, and core's adapter is gone; the gallery's
rotation checks pass on the simulator there without the workaround.

`MPPHolisticLandmarker` fails any image whose orientation is not
`UIImageOrientationUp` ("Unsupported UIImageOrientation"), unlike the other iOS
tasks and unlike Holistic on every other platform. The adapter
(`native/ios/vision_sdk_bridge.mm`) turns the pixels itself and maps the points
back into the caller's frame. On an iPhone 15 Pro the result is 0.008 (CPU) and
0.010 (Metal) from Google's rotated desktop reference.

### UP-016: Android 1.0.0 declares protobuf-javalite but needs protobuf-java

**Status:** reported upstream as
[google-ai-edge/mediapipe#6348](https://github.com/google-ai-edge/mediapipe/issues/6348)
and [#6364](https://github.com/google-ai-edge/mediapipe/issues/6364).
Worked around in `mediapipe_vision` until October 6, 2026, when Android moved
to Google's per-family C libraries, which need no AAR or protobuf.

`tasks-core` 1.0.0's POM declares `protobuf-javalite` 4.26.1, but
`HolisticLandmarkerOptions` calls `Any$Builder.build()` with full protobuf-java's
signature, so Holistic creation fails with `NoSuchMethodError`. No other task
makes that call. The plugin excludes javalite and depends on `protobuf-java`
4.26.1; Face, Hand, Pose, Gesture and Holistic all pass on the emulator with it.

### UP-018: Mobile SDKs mishandle padded rows in CPU pose masks

**Status:** observed September 23 with Google's 1.0.1 iOS XCFrameworks on the
simulator (CPU) and Android tasks-vision 1.0.0 on the emulator (CPU). Worked
around in the iOS adapter; Android fails inside Google's code. Metal and the
Android GPU are unverified. Since October 6, 2026, iOS runs Google's per-family C library through the
same C API path as macOS, and core's adapter is gone; the gallery's padded
mask checks pass on the simulator there without the workaround.
Android also runs Google's per-family C library since then, and the same
checks pass on the arm64 Android emulator (API 31, CPU).

MediaPipe's CPU image frames pad each row to 16 bytes, so a float32 mask whose
width is not a multiple of 4 has padded rows. `MPPPoseLandmarker` and
`MPPHolisticLandmarker` copy a mask as its first width x height floats, so each
row after the first starts further into the previous one. Pose's mask for
`pose.jpg` turned a quarter turn (667 wide) was 0.103 from the upright mask
turned back; read at the padded stride of 668, it is 0.0074, as in Google's
Python wheel. The adapter lays CPU pose masks back out at the padded stride;
the last few values, past the SDK's copy, repeat the row above.

On Android, `PoseLandmarker.detect` itself throws while converting such a mask
("ImageFrame must store data contiguously to be allocated as ByteBuffer"), so
no mask reaches the plugin. `sdk_landmark_tasks_test.dart` expects that error
for the 667-wide case. Holistic's masks take another path and are unaffected
on Android. Camera frames are rarely affected on either platform, since their
widths and heights are multiples of 4.

### UP-019: Android Image Segmenter reports no labels

**Status:** observed September 23 with Android tasks-vision 1.0.0. Worked
around in `mediapipe_vision`. Since October 6, 2026, Android runs Google's per-family C library,
which reports the labels: the gallery's segmenter suite reads all 21 on the
arm64 emulator (API 31, CPU).

`ImageSegmenter.getLabels()` returns an empty list for DeepLab-v3, whose
metadata carries 21 labels (the C API and the iOS SDK report them). Google's
`populateLabels` reads them from the segmentation calculator's options in the
graph config, which `Graph.getCalculatorGraphConfig()` parses with
`ProtoUtil.getExtensionRegistry()`, an empty registry, so the options extension
holding the labels is never read. The plugin parses those options again with
the extension registered and gets all 21 labels in mask order.

### UP-022: Android Interactive Segmenter drops a model buffer

**Status:** observed September 23 with Google's tasks-vision 1.0.0 Android
library on an x64 emulator. Worked around in the Android plugin. Since October 6, 2026, Android runs Google's per-family C library,
whose Interactive Segmenter has not been given a model buffer on Android
yet.

The stateful `InteractiveSegmenter.createFromOptions` with
`BaseOptions.setModelAssetBuffer` fails in the graph ("ExternalFile must
specify at least one of 'file_content', 'file_name', ..." from
`image_segmenter_graph.cc`), while the same model as an absolute
`setModelAssetPath` loads and matches Google's reference. The plugin writes
this task's bytes to a private file in the app's cache directory and deletes it
when the task closes.

### UP-024: Android Image Segmenter GPU category mask is one class low on Adreno

**Status:** observed September 23 on a physical Galaxy S24 (Adreno 750,
Android 16) in Firebase Test Lab, with Google's tasks-vision 1.0.0. Gone with
Google's per-family C library: on October 7, 2026 the same phone's GPU
category mask matched Google's GPU reference on 99.6% of the grid, no class
off by one (Test Lab run 37661319956). The C library returns the GPU mask as
float32 class values (UP-047), which the package rounds; a truncating read of
that float gives exactly this off-by-one.

On the GPU delegate, DeepLab-v3's category mask labels the person in
portrait.jpg as class 14 instead of 15. The class shares are otherwise right
(0.499 background, 0.501 "14" against Google's GPU reference 0.498 and 0.502
for 15), and the confidence masks match that reference within 0.0015 on
average, so only the category values are off by one. Google's wheel on a Mac's
Metal GPU and its Android SDK on a Pixel 8a's Mali GPU report 15. The byte
already arrives as 14 from Google's Java task. The shape suggests a normalized
class value truncated when the GPU result is read back. Apps that need exact
classes on GPU can take the most confident class from the confidence masks.

### UP-033: Android tasks read a model buffer they do not keep

**Status:** observed October 1 with Google's tasks-audio and tasks-text 1.0.0
Android libraries, on a tester's phone and an arm64 API 31 emulator, in release
builds only. Google's documentation does not state the rule; the defect that
shipped was in this repo's plugins, and is fixed there. No upstream issue filed.
Since October 6, 2026, Android runs Google's per-family C library, which
gets the buffer only during the create call, as on every other platform;
vision tasks created from bytes pass that way on the arm64 emulator.

`BaseOptions.Builder.setModelAssetBuffer` accepts only a direct `ByteBuffer` or
a `MappedByteBuffer`: `build()` rejects a heap buffer, the kind
`BaseOptionsUtils` would copy. For a direct buffer it gives native code the
buffer's address (`FilePointerMeta`) and copies nothing, and no Google object
keeps a reference to the buffer. TFLite's constant tensors then point into
memory the caller must keep alive as long as the task, which the Javadoc does
not mention. TFLite's own Java `Interpreter` keeps its model buffer referenced
for this reason, and MediaPipe's C API copies the bytes.

The audio and text plugins held the buffer in a field nothing read. R8 removes
such fields from release builds, so once a garbage collection freed the buffer,
inference read freed memory. Audio Classifier failed with
`rfft2d.cc:454 output_shape.Dims(num_dims_output - 2) != fft_length_data[0] (1 != 0)`
and `interpreter_->Invoke() == kTfLiteOk (1 vs. 0)`, then "Graph has errors"
on every later call. Text Classifier scored a sentence it rates 1.00 positive
at 0.50/0.50, with no error. Debug builds keep the field and never showed it.
Forcing one collection (`kill -10` on the app's process, as root) reproduced
both.

Each plugin now keeps its buffers in a map until the task closes, as the vision
plugin already did. On the same emulator the release gallery then kept its
scores through 3 forced collections in Clips mode and 3 for Text Classifier,
and ran a minute of microphone input through 6 more without an error.
Android CI now builds the release gallery and fails when R8's usage report
lists an instance field removed from the plugins (`tool/ci/check_r8_usage.py`).

### UP-035: iOS Proofreader and Summarizer return their text decoded as Mac Roman

**Status:** observed October 2, 2026 with Google's 1.0.1 iOS SDK
(MediaPipeTasksText and MediaPipeTasksCommon XCFrameworks) on the arm64 iOS
simulator; worked around in core's adapter. No upstream issue filed. Since
October 6, 2026, iOS runs Google's per-family C library, whose C API returns
UTF-8, and core's adapter is gone: the Proofreader and Summarizer Unicode cases
match Google's wheel byte for byte on the simulator without the workaround.

`MPPTextProofreader` and `MPPTextSummarizer` turn the generated UTF-8 bytes
into `NSString`s as if they were Mac Roman: for the input "The café serve
delicious croissants, and María enjoy them." the Proofreader returns
"The caf√© serves delicious croissants, and Mar√≠a enjoys them.", in the
completed result, in every streamed chunk and in the corrections. The model
saw the input correctly (the rest of the sentence is Google's wheel's answer,
byte for byte), so the conversion is on the way out. The classic text tasks
and the Text Embedder, EmbeddingGemma included, are unaffected.

Mac Roman assigns a character to every byte, so the conversion loses nothing:
`text_sdk_bridge.mm` encodes such a string back to Mac Roman and reads the
bytes as UTF-8, and leaves text that is already valid UTF-8 (plain ASCII,
or a correct "é", whose Mac Roman byte is not valid UTF-8) as it is. With
that, every Proofreader and Summarizer case with non-ASCII text matches
Google's macOS 1.0.1 wheel on the simulator.

### UP-039: Android's audio runner reports graph failures only at its close

**Status:** read in Google's v1.0.0 source; not reproduced, since no graph
failure could be forced with a valid model on the API 31 emulator. Documented
in `mediapipe_audio`. No upstream issue filed. Since October 6, 2026, Android
runs Google's audio stream through its per-family C library, as the other
platforms do, so this Java runner no longer applies.

`AudioClassifier.createFromOptions` gives the options' error listener to its
output handler only, which hears result conversion errors. Its `TaskRunner`
has no error listener, so `send` logs a graph error ("Mediapipe error: ...")
and swallows it, and `close` throws it (`TaskRunner.java`). A failure while
streaming therefore reaches the caller only when the stream closes, and a
close that throws skips `graph.tearDown()`. Google's checks at the call itself
do throw: a timestamp that does not increase ("The received packets having a
smaller timestamp than the processed timestamp.") and a changed sample rate
("The input audio sample rate: 48000.0 is inconsistent with the previously
provided: 16000.0"). `mediapipe_audio` checks both in Dart first, and delivers
a failure Google reports at the close on the stream's results during
`dispose()`.

### UP-040: The iOS audio stream's close returns before its delegate has the last results

**Status:** observed October 4, 2026 with Google's 1.0.1 iOS SDK on the arm64
simulator; worked around in core's adapter. No upstream issue filed. Since October 6, 2026, iOS runs Google's per-family C library through the
same C API path as macOS, and core's adapter is gone; the gallery's
audio stream checks pass on the simulator there without the workaround.

`MPPAudioClassifier` hands every stream result to its delegate with
`dispatch_async` on a private serial queue (`MPPAudioClassifier.mm`), and
`closeWithError:` only closes the graph, so it returns before the delegate has
received the results the close flushed: in 56 of 200 runs of a half-second
stream, the tail had not arrived when `closeWithError:` returned. The public
API offers no way to wait for them, and the options hold the delegate weakly.
Core's adapter keeps the delegate strongly, reads the queue with key-value
coding (`_callbackQueue`, present in the 1.0.1 binary) when it creates the
task, and after `closeWithError:` runs an empty block on that queue
synchronously, after which the tail had arrived in 200 of 200 runs. An SDK
that hid the queue would make the adapter refuse stream mode at creation.

## Integration pitfalls resolved in this repo

These are recorded for continuity, not classified as confirmed MediaPipe defects.

- **Borrowed NumPy image lifetime:** `mp.Image.create_from_file(...).numpy_view()`
  can leave a view whose temporary image owner has been released before `.copy()`
  executes. Linux/Windows reference generation segfaulted. Keep the image in a
  named variable through the copy. Fixed in commit `1d6b57c`; this follows the
  API's ownership contract.
- **Windows Dart executable spelling:** `shutil.which('dart')` resolved uppercase
  `dart.EXE`; the Dart 3.12 hook runner attempted `dart.EXE.exe`. Explicitly launch
  Flutter's `dart.bat` wrapper on Windows. Fixed in `acf6cdd`. The runner's
  extension handling is a potential upstream Dart issue; its exact scope has not
  been independently established.
- **Windows Python output encoding:** Flutter's Unicode build marker failed
  while the harness printed logs through cp1252. Configure stdout/stderr as UTF-8.
  Fixed in `6a1329e`; a harness bug.
- **Raw fixture packing:** the official file decoder returns RGBA. Slice to three
  channels and copy before emitting SRGB fixture bytes. An early landmark
  reference pass used the wrong packing and produced misleading empty results.
  Corrected in the generator, and the goldens were regenerated.
- **Gesture category indices:** the C API reports a raw classifier index for
  recognized gestures, and the official Python bindings overwrite it with -1
  because canned and custom classifiers number their labels independently. The
  Dart wrapper reports -1 for the same reason; the documented value is not a
  comparison adjustment.
- **Native asset aliases:** distinct Dart asset IDs cannot share one physical
  library filename. Until October 6, 2026 the desktop hooks used separate
  Face Detector, Face Landmarker and combined-vision aliases of the same
  verified native bytes; every vision task now binds the vision library's one
  asset.
- **Tagged heap pointers on Android:** Android's allocator tags a heap
  pointer's top byte, so an address passed as an `int64` is negative there.
  The text stream bridge marks a lost event with -1 or -2, and its receiver
  took any value below 1 for a marker, so on Android every streamed
  Proofreader and Summarizer request waited forever. Compare the markers
  exactly. Fixed with the move to Google's per-family libraries.

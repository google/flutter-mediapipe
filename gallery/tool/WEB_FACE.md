# Web FaceLandmarker gallery

[Try it now](https://google.github.io/flutter-mediapipe/): open
**Face Landmarker**, allow the camera, and put a face in view. Web currently
supports CPU/WASM and GPU/WebGL 2. Select **GPU** while the camera is running
to recreate the task with Google's GPU delegate. If browser hardware acceleration
or worker WebGL 2 is unavailable, the task reports an error; select CPU and restart.

Chromium CI exercises GPU IMAGE/VIDEO against the official JavaScript GPU
reference and switches live capture CPU → GPU → CPU. Hosted Linux uses
SwiftShader software WebGL; this validates the GPU code path, not physical GPU
performance. The deployed release repeats the live delegate-switch test.

The gallery uses the official checksum-pinned Google Tasks Vision runtime,
with inference on a module worker. Its five live landmark tasks and two live
detectors use Google's DrawingUtils on a worker canvas when supported, for both
CPU and GPU. The Flutter painter remains a fallback when canvas transfer or
worker drawing fails. The worker mirrors shapes but paints labels upright and
scales strokes to the displayed preview. Model, runtime, worker and CanvasKit
assets are self-hosted.

## Local release verification

Requirements: Flutter 3.47.5, Python 3.12, Node 22 and ffmpeg. From the root:

```sh
dart run tool/gallery_builder/bin/prepare_gallery.dart --target web
python3.12 -B gallery/tool/browser/prepare_camera.py
cd gallery/tool/browser
npm ci
npx playwright install chromium firefox
cd ../..
flutter pub get
flutter build web --release --base-href /flutter-mediapipe/ --no-web-resources-cdn
flutter build web --release --base-href /api-probe/ --no-web-resources-cdn --output build/web-api -t tool/web_api_probe.dart
python3.12 -B tool/write_web_build_info.py
cd ..
python3.12 -B gallery/tool/web_server.py
```

In another terminal at the root:

```sh
node gallery/tool/browser/test_browser.mjs
node gallery/tool/browser/test_browser.mjs --browser=firefox --suite=api
```

Hosted Linux runs Firefox headed through `xvfb-run -a`, with software WebGL;
the workflow contains its system dependencies and browser preferences. Full
Chromium is required: Playwright's lightweight headless shell rejects camera
capture. Do not rebuild either bundle while the browser suite is serving it.

The tests exercise real public Dart calls, compare all 478 landmark coordinates,
52 blendshapes and 16 matrix values with the same browser's official JS API,
check padded RGB/RGBA/BGRA, rotations (including negative/full turns), copied
inputs, owned results, invalid models, modes, timestamps, failed-frame recovery
and queued disposal. The camera suite checks actual `getUserMedia` capture,
face/blank/face recovery, responsive preview sizing, two-device selection,
mirroring, permission denial, missing cameras, worker failure/restart, simulated
track-ended events, and track/worker/callback cleanup. It also screenshots the
preview with the overlay hidden and requires the overlay's landmarks within
1.5% (median) of the face the official IMAGE task finds in those pixels, the
native oracle's criterion. Evidence goes to the ignored
`build/ci-tmp/web-browser-*` folders and Actions artifacts.

A MacBook Pro physical webcam has separately returned one face with 478
landmarks across two stop/start sessions. CI webcams are supplied browser
fixtures, not physical devices. Safari and mobile browser validation remain
future work.

## GitHub Pages

`.github/workflows/web.yaml` builds and tests every PR. Successful pushes to
`main` deploy automatically once this workflow is merged there. The initial
implementation branch `feat/web-face-landmarker` also publishes the demo so it
can be tried before merging the native/gallery baseline. Manual workflow runs
on either publishing branch follow the same testing/deployment gates.

The deployment job downloads `web-gallery-release` from the passing browser job,
publishes it through GitHub's Pages/OIDC actions, and never rebuilds it. A final
job verifies the deployed source in `build-info.json`, then runs the camera
suite against the public HTTPS site. Pull requests never publish or receive
Pages write permission. GitHub's repository deployment history links the source
and workflow for each published demo.

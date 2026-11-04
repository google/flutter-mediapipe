# Native provenance

The vision tasks run on Google's MediaPipe vision library, one of the C
libraries Google builds per task family, here from MediaPipe 1.2.0, the
nightly build of October 18, 2026. This package's build hook bundles it as
`package:mediapipe_vision/mediapipe.dylib` through `mediapipe_core`, which pins
every platform's file by SHA-256 and size
(`mediapipe_core/lib/src/native_assets/family_runtimes.dart`). No MediaPipe
code is compiled or patched here, and the library is bundled as Google built
it.

## Bindings

The Dart bindings are generated with ffigen from MediaPipe's C API headers,
which `mediapipe_core` vendors unchanged from the same build
(`mediapipe_core/native/README.md`). The Interactive Segmenter's stateful API
has no header in Google's delivery, so its bindings follow Google's Python
ctypes definitions. The tests check struct sizes and field offsets against
both.

`FaceLandmarksConnections`, `HandLandmarksConnections` and
`PoseLandmarksConnections` are generated from MediaPipe 1.0.0's official Python
drawing topology, keeping every edge and its order.

## Notices

Google's `LICENSE` and `NOTICE` for the bundled library are the ones its
October 9, 2026 build ships with every family, which `mediapipe_core` carries
once (`mediapipe_core/third_party/`).
`OPENCV_CAROTENE_NOTICES` holds OpenCV 4.12.0's hal/carotene notices, which the
package's former source-built runtime needed; it stays until Google confirms
the notices its own libraries need.

## Reference outputs

The tests compare the bundled library with Google's own Python API from its
1.1.0 release candidate: the `mediapipe-nightly` 1.1.0rc20260925 wheel for
macOS arm64, which `mediapipe_core`'s `referenceWheels` pins together with
its C library. Google's first 1.1.1 wheel (1.1.1rc20261013, October 13) is
not pinned until Google says whether 1.1.1's Metal output is intended
(UP-057). The wheel is an independent oracle, not the application runtime.

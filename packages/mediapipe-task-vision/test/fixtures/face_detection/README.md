# Face Detector integration fixtures

Five original sample images copied unchanged, at the maintainer's request, from
[face_detection_tflite](https://github.com/hugocornellier/face_detection_tflite/tree/50c784adaa9f40c722affb1d4412674f25e1fe0c/assets/samples).
The source files had no local changes at the recorded revision. The source
repository's license is preserved in [SOURCE_LICENSE](SOURCE_LICENSE).

[manifest.json](manifest.json) records the exact source revision, paths, SHA-256
digests, encoded sizes, and image dimensions. The images total about 2.3 MB and
are checked in so integration tests will not need a neighboring repository or
network access to obtain their inputs. They are test fixtures, not Flutter
application assets.

| Image | Intended coverage |
| --- | --- |
| `landmark-ex1.jpg` | Close-up portrait |
| `face-landmarks-ex1.jpeg` | High-resolution, non-square image |
| `iris-detection-ex1.jpg` | Turned head |
| `iris-detection-ex2.jpg` | Directional lighting and head covering |
| `group-shot-bounding-box-ex1.jpeg` | Four visible faces, smaller faces, glasses |

## Reference outputs

`official_reference.json` contains results generated through the official
Python API of Google's 1.1.0 release candidate wheel (`mediapipe-nightly` 1.1.0rc20260925 for macOS arm64, core's `referenceWheels`), on macOS arm64 with the CPU delegate and IMAGE
mode. It records the runtime, model, library and input hashes, confidence 0.5,
suppression 0.3, and per-case rotation. Goldens are independent of the Dart wrapper.

The original portrait images each produce one detection. The wide group photo
produces zero at those settings despite containing four people; this is an
intentional regression case for the short-range model.

`portrait-301x209.rgb` is generated from the official decoder's pixels for
`face-landmarks-ex1.jpeg`, taking every twentieth row and column. Its hash is recorded in
the reference JSON. It provides a compact odd-width RGB input that needs no
decoder in tests. The generator also creates RGBA, rotated, and cropped/duplicated
two-face inputs from those pixels, plus an all-zero blank input.

The native suite checks result order, counts, boxes (within one pixel), category
scores and normalized keypoints (within 0.00001). Dart follows Python's treatment
of empty optional strings as null. Missing keypoint confidence is null in Dart,
while Python exposes the C field's 0.0 default. No geometry is adjusted to match.

The suite also exercises model buffers, initialization errors, image errors,
immutable copied results, repeated queued inference and idempotent disposal.
Regenerate deliberately with `tool/generate_face_detector_reference.py` in a
separate Python 3.12 environment holding that wheel; review numerical changes
before accepting new goldens. Ordinary tests consume these checked-in files.

`official_video_reference.json` records a seven-frame sequence through Google's
official VIDEO-mode API at timestamps 0–198 ms. It includes repeated portraits,
a blank frame, a two-face frame, and a rotated frame, all on one detector. The
Dart test submits that sequence in order and checks timestamp/result pairing,
including disposal while frames are queued. Padded RGB, RGBA, and macOS BGRA
variants of the raw portrait separately verify camera-buffer conversion without
changing the official detection outputs.

`official_gpu_reference.json` and `official_gpu_video_reference.json` use the
same independent wheel with `--delegate gpu`, which confirms Metal creation.
RGB frames gain an opaque alpha channel for Apple's GPU upload; the original
RGB values and task pipeline are unchanged. Both delegates run the same test
coverage with the same detector tolerances above, each against its own reference.

These checked-in GPU outputs describe the physical M4 Max development Mac.
CI uses independently generated outputs from the exact pinned official wheel
on its own runner through `MEDIAPIPE_GPU_REFERENCE_DIR`. It retains the same
detector tolerances and validates reference provenance/digests; CPU references
are never redirected. See [the GPU comparison guide](../../../tool/GPU_VALIDATION.md).

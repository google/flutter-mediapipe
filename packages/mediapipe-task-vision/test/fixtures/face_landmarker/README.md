# Official Face Landmarker references

Generated with Google's 1.1.0 release candidate wheel (`mediapipe-nightly` 1.1.0rc20260925 for macOS arm64, core's `referenceWheels`), CPU delegate, and the unmodified Face Landmarker
float16 version 1 bundle.
The JSON records the model, wheel library and raw-image hashes.
Photographs and their provenance/license remain in [../face_detection](../face_detection).

Ten IMAGE inputs include five photographs, RGB/RGBA pixels, two faces, a rotated
image, and a blank frame. Two VIDEO sequences cover single-face smoothing,
multi-face tracking, face loss, re-entry, and rotation. All 478 landmarks,
52 blendshape scores, optional fields, face ordering, and 4×4 transforms are
compared, including the C column-major to Python row/column representation.

Native builds can differ numerically from Google's wheel. On the development
Mac, maximum absolute differences across these cases were 0.0000506 for landmark
coordinates, 0.000930 for blendshape scores, and 0.002392 for matrix elements.
Tests allow 0.0001, 0.002, and 0.005 respectively, with exact counts and metadata.
These are numeric tolerances, not changes to preprocessing, models, or graphs.

Regenerate with `tool/generate_face_landmarker_reference.py` in the pinned Python
environment. That script also copies the official drawing connections into Dart.
The tests use checked-in JSON and need no Python installation.

`official_gpu_reference.json` is generated independently with the same official
wheel and `--delegate gpu`. The wheel confirms creation of the Metal delegate.
RGB input is expanded to RGBA with opaque alpha before entering the graph because
Apple's GPU image upload does not support three-channel ImageFrames. No model,
graph, coordinates, or reference result is modified to match the Dart wrapper.

On the Apple M4 Max development Mac, maximum absolute differences from the wheel's
GPU results across all stills, tracking sequences and padded input tests were
0.00147671 for coordinates, 0.0290841 for blendshape scores, and 0.0431214 for
matrix elements. GPU tests allow 0.002, 0.04, and 0.06 respectively. Counts,
ordering, optional fields, timestamps, and category names still match exactly.
These measurements describe this fixture suite, not model accuracy in general.
CPU tolerances remain unchanged; CPU and GPU are not expected to be bit-identical.

CI generates the GPU oracle on the same runner as the native task, using the
exact pinned official wheel and the same model/fixtures. All tolerances above
remain unchanged. The physical-Mac goldens remain available for local runs.
See [the GPU comparison guide](../../../tool/GPU_VALIDATION.md).

The official wheel's own CPU results also drift between hosts, so every job that
compares a native runtime with these goldens regenerates them on its own host
first. On the Linux and Windows runners the checked-in goldens sit up to
0.0000280 (coordinates), 0.000553 (blendshapes) and 0.00242 (matrix elements)
from that host's official wheel. A desktop job reaches its host reference
through `MEDIAPIPE_CPU_REFERENCE_DIR`; a packaged mobile consumer reads bundled
assets instead, so its runner substitutes the host reference in place and ships
the receipt beside it. `tool/cpu_reference.py` writes both, and the suites
reject any reference that does not match the receipt travelling with it.

Passing runs also print their measured maxima per delegate and value group, and
mobile runners copy that into `report.json`. Tolerances stay as measured above;
the receipt only records how much headroom a run actually had.

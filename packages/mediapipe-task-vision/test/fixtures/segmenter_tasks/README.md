# Image Segmenter references

The inputs are `landmark-ex1.jpg` and the raw `portrait-301x209.rgb` from
`../face_detection/`. `official_reference.json` (CPU) and
`official_gpu_reference.json` (GPU) hold Google's DeepLab-v3 outputs through
the official Python API of the wheel in core's `referenceWheels` for macOS
arm64 (`mediapipe-nightly` 1.1.0rc20260925). Each records the runtime,
library, model and input hashes.

For file inputs the files also keep coarse views of each mask (cell means on a
16 by 12 grid for confidence masks, cell-centre classes on a 32 by 24 grid for
category masks), for runtimes that decode the JPEG themselves and so differ in
the exact bytes.

Regenerate with `tool/generate_segmenter_tasks_reference.py` (add
`--delegate gpu` for the GPU file) in a Python environment holding that wheel,
and review numerical changes before accepting them. CI jobs generate same-host
references with `tool/cpu_reference.py` and `tool/prepare_gpu_reference.py`.
Ordinary tests read the checked-in files.

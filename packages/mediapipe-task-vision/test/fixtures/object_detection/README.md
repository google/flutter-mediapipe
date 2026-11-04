# Object Detector references

The inputs are the Face Detector fixtures in `../face_detection/`, including
the raw `portrait-301x209.rgb`. The four files hold Google's EfficientDet-Lite0
outputs (score threshold 0.3, at most five results) through the official
Python API of the wheel in core's `referenceWheels` for macOS arm64
(`mediapipe-nightly` 1.1.0rc20260925):

| File | Delegate | Mode |
| --- | --- | --- |
| `official_reference.json` | CPU | IMAGE |
| `official_video_reference.json` | CPU | VIDEO |
| `official_gpu_reference.json` | GPU | IMAGE |
| `official_gpu_video_reference.json` | GPU | VIDEO |

Each records the runtime, library, model and input hashes.

Regenerate with `tool/generate_object_detector_reference.py` (add
`--delegate gpu` for the GPU files) in a Python environment holding that
wheel, and review numerical changes before accepting them. Google's 1.0.1
macOS wheel cannot produce them: every graph with a
TensorsToDetectionsCalculator aborts on its macOS CPU path (upstream #6356).
CI jobs generate same-host references with `tool/cpu_reference.py` and
`tool/prepare_gpu_reference.py`. Ordinary tests read the checked-in files.

# Image Classifier and Image Embedder references

The inputs are the Face Detector fixtures in `../face_detection/`.
`official_reference.json` (CPU) and `official_gpu_reference.json` (GPU) hold
Google's outputs for EfficientNet-Lite0 (classifier) and MobileNetV3-Small
(embedder) through the official Python API of the wheel in core's
`referenceWheels` for macOS arm64 (`mediapipe-nightly` 1.1.0rc20260925). The
generator pins both models' SHA-256, and each file records the runtime,
library, model and input hashes.

Regenerate with `tool/generate_image_tasks_reference.py` (add
`--delegate gpu` for the GPU file) in a Python environment holding that wheel,
and review numerical changes before accepting them. CI jobs generate same-host
references with `tool/cpu_reference.py` and `tool/prepare_gpu_reference.py`.
Ordinary tests read the checked-in files.

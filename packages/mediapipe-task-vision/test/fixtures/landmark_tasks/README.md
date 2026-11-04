# Hand, Gesture, Pose and Holistic references

`thumb_up.jpg`, `right_hands.jpg` and `pose.jpg` are the inputs;
`tool/generate_landmark_tasks_reference.py` pins their SHA-256 and refuses any
other file. Each `.rgb` file is the official decoder's RGB pixels for the JPEG
of the same name, written by the generator so tests need no decoder.

`official_reference.json` (CPU) and `official_gpu_reference.json` (GPU) hold
Google's outputs through the official Python API of the wheel in core's
`referenceWheels` for macOS arm64 (`mediapipe-nightly` 1.1.0rc20260925). Each
records the runtime, library, model and input hashes.

Regenerate with `tool/generate_landmark_tasks_reference.py` (add
`--delegate gpu` for the GPU file) in a Python environment holding that wheel,
and review numerical changes before accepting them. The wheel's results drift
between hosts, so CI jobs generate same-host references
(`tool/cpu_reference.py`, `tool/prepare_gpu_reference.py`). Ordinary tests read
the checked-in files.

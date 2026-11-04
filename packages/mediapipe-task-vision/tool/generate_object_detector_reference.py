"""Regenerate reviewed goldens with Google's official macOS arm64 Python API.

Run from the package root in a Python 3.12 venv with the host's pinned runtime
from official_face_runtime.py (core's referenceWheels row for this host).
Google's 1.0.1 macOS wheel is avoided: every graph with a
TensorsToDetectionsCalculator aborts on macOS CPU there (upstream #6356), which
includes this task; 1.1.0 has the fix.

The Dart tests consume the checked-in JSON; they do not need Python.
"""
import argparse
import dataclasses
import json
from pathlib import Path
import platform
from official_face_runtime import (LIBRARY_NAME, LIBRARY_SHA256, RUNTIME,
                                   SOURCE_REVISION, VERSION)
from model_pins import model_sha256  # noqa: E402  (core/tool, via official_face_runtime)
from tool_helpers import digest, reference_json  # noqa: E402

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision.core.image_processing_options import ImageProcessingOptions

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "test/fixtures/object_detection"
# The input images are shared with the face fixtures; only the goldens differ.
IMAGES = ROOT / "test/fixtures/face_detection"
MODEL = ROOT / "models/efficientdet_lite0.tflite"
MODEL_SHA256 = model_sha256('efficientdet_lite0.tflite')
SCORE_THRESHOLD = 0.3
MAX_RESULTS = 5


# TODO: Share this helper and the rest this file repeats from
# generate_face_detector_reference.py, and the image loading and JSON envelope
# the image and segmenter generators repeat, in one vision_cases.py with each
# task's spec, at the next regeneration on the pinned wheel.
def gpu_image(image):
    """Apple's GPU upload requires RGBA; preserve RGB values and add alpha."""
    if image.image_format != mp.ImageFormat.SRGB:
        return image
    pixels = image.numpy_view()
    return mp.Image(image_format=mp.ImageFormat.SRGBA, data=np.concatenate(
        [pixels, np.full((*pixels.shape[:2], 1), 255, dtype=np.uint8)], axis=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--delegate", choices=("cpu", "gpu"), default="cpu")
    parser.add_argument("--output-dir", type=Path,
                        help="Write independent references here without changing fixtures")
    args = parser.parse_args()
    output = args.output_dir.resolve() if args.output_dir else FIXTURES
    output.mkdir(parents=True, exist_ok=True)
    delegate = getattr(mp.tasks.BaseOptions.Delegate, args.delegate.upper())
    suffix = "_gpu" if args.delegate == "gpu" else ""
    assert mp.__version__ == VERSION, mp.__version__
    assert digest(MODEL) == MODEL_SHA256
    library = Path(mp.__file__).parent / "tasks/c" / LIBRARY_NAME
    assert digest(library) == LIBRARY_SHA256
    manifest = json.loads((IMAGES / "manifest.json").read_text())
    cases = []
    options = vision.ObjectDetectorOptions(
        base_options=mp.tasks.BaseOptions(
            model_asset_path=str(MODEL),
            delegate=delegate,
        ),
        score_threshold=SCORE_THRESHOLD,
        max_results=MAX_RESULTS,
    )
    with vision.ObjectDetector.create_from_options(options) as detector:
        def record(name, image, *, rotation=0, file=None, raw=None):
            if args.delegate == "gpu":
                image = gpu_image(image)
            result = detector.detect(
                image, ImageProcessingOptions(rotation_degrees=rotation)
            )
            case = dict(
                name=name, width=image.width, height=image.height,
                rotation_degrees=rotation, **dataclasses.asdict(result)
            )
            if file is not None:
                case.update(file=file.name, sha256=digest(file))
            if raw is not None:
                case.update(raw=raw.name, sha256=digest(raw))
            cases.append(case)
            print(name, len(result.detections), "object(s)")
        for entry in manifest["files"]:
            file = IMAGES / entry["file"]
            assert digest(file) == entry["sha256"]
            record(entry["file"], mp.Image.create_from_file(str(file)), file=file)

        # The same decimation the face fixtures use, so both tasks read one
        # checked-in raw buffer and no test depends on a JPEG decoder.
        decoded = mp.Image.create_from_file(
            str(IMAGES / "face-landmarks-ex1.jpeg")
        )
        # numpy_view borrows native storage; retain its owner until copying.
        pixels = decoded.numpy_view()[::20, ::20, :3].copy()
        raw = IMAGES / "portrait-301x209.rgb"
        assert raw.read_bytes() == pixels.tobytes(), "Raw fixture derivation changed"
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=pixels)
        record("rgb", image, raw=raw)
        rgba = np.concatenate(
            [pixels, np.full((*pixels.shape[:2], 1), 255, dtype=np.uint8)], axis=2
        )
        record("rgba", mp.Image(image_format=mp.ImageFormat.SRGBA, data=rgba), raw=raw)
        # Rotate input counterclockwise, then let MediaPipe correct it clockwise.
        record(
            "rgb-rotated", mp.Image(
                image_format=mp.ImageFormat.SRGB,
                data=np.ascontiguousarray(np.rot90(pixels)),
            ), rotation=90, raw=raw
        )
        record("blank", mp.Image(
            image_format=mp.ImageFormat.SRGB,
            data=np.zeros((480, 640, 3), dtype=np.uint8)
        ))

    reference = dict(
        runtime=RUNTIME,
        source_revision=SOURCE_REVISION,
        library_sha256=LIBRARY_SHA256,
        model_sha256=MODEL_SHA256,
        platform=f"{platform.system()} {platform.machine()}", delegate=args.delegate.upper(), running_mode="IMAGE",
        score_threshold=SCORE_THRESHOLD, max_results=MAX_RESULTS,
        raw_derivation="face-landmarks-ex1.jpeg official RGB decoder, [::20, ::20, :3]",
        **({"input_conversion": "RGB to RGBA with opaque alpha for Metal"}
           if args.delegate == "gpu" else {}),
        cases=cases,
    )
    (output / f"official{suffix}_reference.json").write_text(
        reference_json(reference, allow_nan=False) + "\n"
    )

    video_cases = []
    frames = [
        ("rgb", pixels, 0), ("rgb", pixels, 0),
        ("blank", np.zeros((209, 301, 3), dtype=np.uint8), 0),
        ("rgb", pixels, 0),
        ("rgb-rotated", np.ascontiguousarray(np.rot90(pixels)), 90),
    ]
    options.running_mode = vision.RunningMode.VIDEO
    with vision.ObjectDetector.create_from_options(options) as detector:
        for index, (name, data, rotation) in enumerate(frames):
            image = mp.Image(image_format=mp.ImageFormat.SRGB, data=data)
            if args.delegate == "gpu":
                image = gpu_image(image)
            timestamp = index * 33
            result = detector.detect_for_video(image, timestamp,
                ImageProcessingOptions(rotation_degrees=rotation))
            case = dict(name=name, width=image.width, height=image.height,
                        timestamp_ms=timestamp, rotation_degrees=rotation,
                        **dataclasses.asdict(result))
            if name != "blank":
                case.update(raw=raw.name, sha256=digest(raw))
            video_cases.append(case)
            print("video", timestamp, name, len(result.detections), "object(s)")
    (output / f"official{suffix}_video_reference.json").write_text(reference_json(
        {**reference, "running_mode": "VIDEO", "cases": video_cases},
        allow_nan=False) + "\n")


if __name__ == "__main__":
    main()

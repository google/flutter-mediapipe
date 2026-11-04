"""Generate Face Landmarker goldens with Google's pinned Python wheel.

Uses the same verified photographs and independent runtime as the detector
goldens. Dart consumers need neither Python nor the native build toolchain.
"""
import argparse
import dataclasses
import json
from pathlib import Path

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision.core.image_processing_options import ImageProcessingOptions

from generate_face_detector_reference import ROOT, FIXTURES, LIBRARY_SHA256, digest, gpu_image
from model_pins import model_sha256  # noqa: E402  (core/tool, via official_face_runtime)
from official_face_runtime import LIBRARY_NAME, RUNTIME, SOURCE_REVISION, VERSION

MODEL = ROOT / "models/face_landmarker.task"
MODEL_SHA256 = model_sha256('face_landmarker.task')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--delegate", choices=("cpu", "gpu"), default="cpu")
    parser.add_argument("--output-dir", type=Path,
                        help="Write references here without changing fixtures or topology")
    args = parser.parse_args()
    delegate = getattr(mp.tasks.BaseOptions.Delegate, args.delegate.upper())
    suffix = "_gpu" if args.delegate == "gpu" else ""
    assert mp.__version__ == VERSION
    assert digest(MODEL) == MODEL_SHA256
    assert digest(__import__('pathlib').Path(mp.__file__).parent /
                  "tasks/c" / LIBRARY_NAME) == LIBRARY_SHA256
    manifest = json.loads((FIXTURES / "manifest.json").read_text())
    raw = FIXTURES / "portrait-301x209.rgb"
    pixels = np.frombuffer(raw.read_bytes(), dtype=np.uint8).reshape(209, 301, 3)
    pair = np.ascontiguousarray(np.concatenate(
        [pixels[:, 60:240, :], pixels[:, 60:240, :]], axis=1))
    images = {}
    for entry in manifest["files"]:
        file = FIXTURES / entry["file"]
        assert digest(file) == entry["sha256"]
        images[file.name] = mp.Image.create_from_file(str(file))
    arrays = dict(rgb=pixels, rgba=np.concatenate(
        [pixels, np.full((209, 301, 1), 255, dtype=np.uint8)], axis=2),
        pair=pair, rotated=np.ascontiguousarray(np.rot90(pixels)),
        blank=np.zeros((209, 301, 3), dtype=np.uint8))
    images.update({name: mp.Image(
        image_format=mp.ImageFormat.SRGBA if name == 'rgba' else mp.ImageFormat.SRGB,
        data=data) for name, data in arrays.items()})
    cases = []
    for mode, num_faces, names in [
        (vision.RunningMode.IMAGE, 2, list(images)),
        (vision.RunningMode.VIDEO, 1, ['rgb', 'rgb', 'blank', 'rgb', 'rotated', 'rgb']),
        (vision.RunningMode.VIDEO, 2, ['pair', 'pair', 'blank', 'rgb', 'pair']),
    ]:
        options = vision.FaceLandmarkerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_path=str(MODEL),
                delegate=delegate),
            running_mode=mode, num_faces=num_faces,
            output_face_blendshapes=True,
            output_facial_transformation_matrixes=True)
        with vision.FaceLandmarker.create_from_options(options) as task:
            frames = []
            for index, name in enumerate(names):
                image = images[name]
                if args.delegate == 'gpu':
                    image = gpu_image(image)
                rotation = 90 if name == 'rotated' else 0
                processing = ImageProcessingOptions(rotation_degrees=rotation)
                result = (task.detect(image, processing) if mode == vision.RunningMode.IMAGE
                          else task.detect_for_video(image, index * 33, processing))
                frames.append(dict(name=name, width=image.width, height=image.height,
                    rotation=rotation, timestamp_ms=index * 33 if mode == vision.RunningMode.VIDEO else None,
                    **dataclasses.asdict(result)))
                print(mode.name, num_faces, name, len(result.face_landmarks), 'face(s)', flush=True)
            cases.append(dict(mode=mode.name, num_faces=num_faces, frames=frames))
    output = args.output_dir.resolve() if args.output_dir else FIXTURES.parent / 'face_landmarker'
    output.mkdir(parents=True, exist_ok=True)
    (output / f'official{suffix}_reference.json').write_text(json.dumps(dict(
        runtime=RUNTIME, delegate=args.delegate.upper(),
        source_revision=SOURCE_REVISION,
        library_sha256=LIBRARY_SHA256, model_sha256=MODEL_SHA256,
        **({'input_conversion': 'RGB to RGBA with opaque alpha for Metal'}
           if args.delegate == 'gpu' else {}),
        raw_sha256=digest(raw), cases=cases),
        default=lambda value: value.tolist(), allow_nan=False, separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()

"""Independent Hand, Gesture, Pose and Holistic outputs from the official wheel."""
import argparse
import dataclasses
import json
from pathlib import Path

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision.core.image_processing_options import ImageProcessingOptions
from official_face_runtime import (LIBRARY_NAME, LIBRARY_SHA256, RUNTIME,
                                   SOURCE_REVISION, VERSION)
from model_pins import model_sha256  # noqa: E402  (core/tool, via official_face_runtime)
from tool_helpers import digest, reference_json  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'test/fixtures/landmark_tasks'
MODELS = {
    'hand': ('hand_landmarker.task', model_sha256('hand_landmarker.task')),
    'gesture': ('gesture_recognizer.task', model_sha256('gesture_recognizer.task')),
    'pose': ('pose_landmarker_lite.task', model_sha256('pose_landmarker_lite.task')),
    'holistic': ('holistic_landmarker.task', model_sha256('holistic_landmarker.task')),
}
FILES = {
    'thumb_up.jpg': '5d673c081ab13b8a1812269ff57047066f9c33c07db5f4178089e8cb3fdc0291',
    'right_hands.jpg': '4b5134daa4cb60465535239535f9f74c2842aba3aa5fd30bf04ef5678f93d87f',
    'pose.jpg': 'c8a830ed683c0276d713dd5aeda28f415f10cd6291972084a40d0d8b934ed62b',
}


def use_header_holistic_order():
    """Makes Google's Python write Holistic's thresholds where the library reads them.

    The wheels' ctypes declare the three pose thresholds before the hand
    threshold, but the compiled library reads the public header's order (hand
    first), so every non-default threshold lands on the wrong field (UP-005 in
    upstream-issues.md). Slot i receives the header's i-th
    threshold, which is what the Dart wrapper writes on every platform.
    """
    from mediapipe.tasks.python.vision import holistic_landmarker as holistic
    wheel = ('min_pose_detection_confidence', 'min_pose_suppression_threshold',
             'min_pose_landmarks_confidence', 'min_hand_landmarks_confidence')
    header = ('min_hand_landmarks_confidence', 'min_pose_detection_confidence',
              'min_pose_suppression_threshold', 'min_pose_landmarks_confidence')
    fields = [name for name, *_ in holistic.MpHolisticLandmarkerOptionsC._fields_]
    # A future wheel that fixes its ctypes would make this rearrangement wrong.
    assert tuple(name for name in fields if name in wheel) == wheel, fields
    original = holistic.MpHolisticLandmarkerOptionsC.from_c_options

    def header_order(*positional, **options):
        values = [options[name] for name in header]
        options.update(zip(wheel, values))
        return original(*positional, **options)
    holistic.MpHolisticLandmarkerOptionsC.from_c_options = header_order


def mask_output(mask):
    data = mask.numpy_view().copy()
    return dict(width=mask.width, height=mask.height,
                samples=data[::17, ::19].reshape(-1).tolist(),
                minimum=float(data.min()), maximum=float(data.max()), mean=float(data.mean()))


def result_output(result):
    output = {}
    for field in dataclasses.fields(result):
        value = getattr(result, field.name)
        if field.name == 'segmentation_masks':
            output[field.name] = None if value is None else [mask_output(v) for v in value]
        elif field.name == 'segmentation_mask':
            output[field.name] = None if value is None else mask_output(value)
        else:
            output[field.name] = None if value is None else json.loads(json.dumps(value,
                default=lambda v: dataclasses.asdict(v)))
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--delegate', choices=['cpu', 'gpu'], default='cpu')
    parser.add_argument('--output-dir', type=Path, default=FIXTURES)
    # GPU references cover the tasks whose GPU path the package offers.
    parser.add_argument('--tasks', default=','.join(MODELS),
                        help='Comma-separated subset of ' + ', '.join(MODELS))
    # Google's desktop GPU paths cannot give Pose's float masks (Metal fails,
    # UP-028; OpenGL ES returns 8-bit RGBA images, UP-030); the package
    # refuses masks on those GPUs.
    parser.add_argument('--no-pose-masks', action='store_true')
    args = parser.parse_args()
    selected = args.tasks.split(',')
    if not selected or not set(selected) <= MODELS.keys():
        raise SystemExit('Unknown landmark task in --tasks: ' + args.tasks)
    assert mp.__version__ == VERSION
    use_header_holistic_order()
    assert digest(Path(mp.__file__).parent / 'tasks/c' / LIBRARY_NAME) == LIBRARY_SHA256
    for task_name in selected:
        name, sha = MODELS[task_name]
        assert digest(ROOT / 'models' / name) == sha
    for name, sha in FILES.items():
        assert digest(FIXTURES / name) == sha
    decoded = {}
    for name in FILES:
        image = mp.Image.create_from_file(str(FIXTURES / name))
        # The C image decoder returns RGBA; packed SRGB fixtures need 3 channels.
        decoded[name] = image.numpy_view()[:, :, :3].copy()
        (FIXTURES / name.replace('.jpg', '.rgb')).write_bytes(decoded[name].tobytes())
    cases = []
    delegate = getattr(mp.tasks.BaseOptions.Delegate, args.delegate.upper())
    for task_name, (model_name, model_sha) in MODELS.items():
        if task_name not in selected:
            continue
        task_type = {'hand': vision.HandLandmarker, 'gesture': vision.GestureRecognizer,
                     'pose': vision.PoseLandmarker, 'holistic': vision.HolisticLandmarker}[task_name]
        option_type = getattr(vision, task_type.__name__ + 'Options')
        base = mp.tasks.BaseOptions(model_asset_path=str(ROOT / 'models' / model_name), delegate=delegate)
        configuration = dict(num_hands=2) if task_name in ('hand', 'gesture') else (
            dict(output_segmentation_masks=not args.no_pose_masks) if task_name == 'pose' else
            dict(output_face_blendshapes=True, output_segmentation_mask=True))
        configurations = [configuration]
        if task_name == 'holistic':
            configurations.append({**configuration, 'min_hand_landmarks_confidence': 0.99,
                'min_pose_detection_confidence': 0.11, 'min_pose_suppression_threshold': 0.31,
                'min_pose_landmarks_confidence': 0.43})
        sample = 'thumb_up.jpg' if task_name in ('hand', 'gesture') else 'pose.jpg'
        for configuration in configurations:
            for mode in [vision.RunningMode.IMAGE, vision.RunningMode.VIDEO]:
                options = option_type(base_options=base, running_mode=mode, **configuration)
                inputs = [(name, 'file') for name in FILES] + [(sample, v) for v in ['rgb', 'rgba', 'blank', 'rotated']]
                if mode == vision.RunningMode.VIDEO:
                    inputs = [(sample, 'rgb'), (sample, 'blank'), (sample, 'rgb')]
                # VIDEO frames deliberately share one task. IMAGE requests are independent,
                # and 1.0.0's Holistic mask smoothing otherwise keeps the previous image's
                # dimensions, so build a fresh task per IMAGE input as the Dart tests do.
                tracked = task_type.create_from_options(options) if mode == vision.RunningMode.VIDEO else None
                for index, (name, kind) in enumerate(inputs):
                    rotation = 90 if kind == 'rotated' else 0
                    if kind == 'file':
                        image = mp.Image.create_from_file(str(FIXTURES / name))
                    else:
                        pixels = np.zeros_like(decoded[name]) if kind == 'blank' else decoded[name].copy()
                        if kind == 'rotated':
                            pixels = np.ascontiguousarray(np.rot90(pixels))
                        rgba = kind == 'rgba' or args.delegate == 'gpu'
                        if rgba:
                            pixels = np.concatenate([pixels, np.full((*pixels.shape[:2], 1), 255, dtype=np.uint8)], axis=2)
                        image = mp.Image(image_format=mp.ImageFormat.SRGBA if rgba else mp.ImageFormat.SRGB, data=pixels)
                    processing = ImageProcessingOptions(rotation_degrees=rotation)
                    timestamp = index * 33 if mode == vision.RunningMode.VIDEO else None
                    task = tracked or task_type.create_from_options(options)
                    try:
                        if timestamp is None:
                            method = task.recognize if task_name == 'gesture' else task.detect
                            result = method(image, processing)
                        else:
                            method = task.recognize_for_video if task_name == 'gesture' else task.detect_for_video
                            result = method(image, timestamp, processing)
                        # Read masks while their task is alive.
                        payload = result_output(result)
                    finally:
                        if tracked is None:
                            task.close()
                    raw = name.replace('.jpg', '.rgb')
                    cases.append(dict(task=task_name, input=kind, file=name, sha256=FILES[name],
                        raw=raw, raw_sha256=digest(FIXTURES / raw), width=image.width, height=image.height,
                        rotation_degrees=rotation, timestamp_ms=timestamp, options=configuration,
                        result=payload))
                    print(task_name, mode.name, kind, name, flush=True)
                if tracked is not None:
                    tracked.close()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = dict(runtime=RUNTIME, delegate=args.delegate.upper(),
        source_revision=SOURCE_REVISION, library_sha256=LIBRARY_SHA256,
        models={name: sha for name, (_, sha) in MODELS.items() if name in selected},
        cases=cases)
    # Same names as the face suites: the Dart loader reads GPU references
    # from MEDIAPIPE_GPU_REFERENCE_DIR by the `_gpu_` in the file name.
    name = 'official_gpu_reference.json' if args.delegate == 'gpu' else 'official_reference.json'
    (args.output_dir / name).write_text(reference_json(output) + '\n')


if __name__ == '__main__':
    main()

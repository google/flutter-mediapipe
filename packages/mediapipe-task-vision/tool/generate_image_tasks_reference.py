"""Independent Image Classifier/Embedder outputs from a pinned official wheel."""
import argparse
import dataclasses
import json
from pathlib import Path
import platform

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.components.containers import rect
from mediapipe.tasks.python.vision.core.image_processing_options import ImageProcessingOptions
from official_face_runtime import (LIBRARY_NAME, LIBRARY_SHA256, RUNTIME,
                                   SOURCE_REVISION, VERSION)
from model_pins import model_sha256  # noqa: E402  (core/tool, via official_face_runtime)
from tool_helpers import digest, reference_json  # noqa: E402
from official_embedding_layout import use_header_embedding_layout  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'test/fixtures/face_detection'
MODELS = {
    'classifier': ('efficientnet_lite0.tflite',
        model_sha256('efficientnet_lite0.tflite')),
    'embedder': ('mobilenet_v3_small.tflite',
        model_sha256('mobilenet_v3_small.tflite')),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--delegate', choices=['cpu', 'gpu'], default='cpu')
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'test/fixtures/image_tasks')
    # Google's Linux 1.0.1 runtime aborts the embedder on GPU (UP-027).
    parser.add_argument('--tasks', default=','.join(MODELS),
                        help='Comma-separated subset of ' + ', '.join(MODELS))
    args = parser.parse_args()
    use_header_embedding_layout('vision')
    selected = args.tasks.split(',')
    if not selected or not set(selected) <= MODELS.keys():
        raise SystemExit('--tasks must name some of ' + ', '.join(MODELS))
    assert mp.__version__ == VERSION
    assert digest(Path(mp.__file__).parent / 'tasks/c' / LIBRARY_NAME) == LIBRARY_SHA256
    for name, sha in MODELS.values():
        assert digest(ROOT / 'models' / name) == sha
    raw = FIXTURES / 'portrait-301x209.rgb'
    pixels = np.frombuffer(raw.read_bytes(), dtype=np.uint8).reshape(209, 301, 3).copy()
    delegate = getattr(mp.tasks.BaseOptions.Delegate, args.delegate.upper())
    cases = []

    def image_for(kind):
        if kind == 'file':
            return mp.Image.create_from_file(str(FIXTURES / 'landmark-ex1.jpg'))
        value = np.zeros_like(pixels) if kind == 'blank' else pixels
        if kind == 'rotated':
            value = np.ascontiguousarray(np.rot90(value))
        if kind == 'rgba' or args.delegate == 'gpu':
            value = np.concatenate([value, np.full((*value.shape[:2], 1), 255, dtype=np.uint8)], axis=2)
            return mp.Image(image_format=mp.ImageFormat.SRGBA, data=value)
        return mp.Image(image_format=mp.ImageFormat.SRGB, data=value)

    for task_name, (model_name, model_sha) in MODELS.items():
        if task_name not in selected:
            continue
        base = mp.tasks.BaseOptions(model_asset_path=str(ROOT / 'models' / model_name), delegate=delegate)
        factory = vision.ImageClassifier.create_from_options if task_name == 'classifier' else vision.ImageEmbedder.create_from_options
        option_sets = [dict(max_results=3, score_threshold=0.0)] if task_name == 'classifier' else [
            dict(l2_normalize=False, quantize=False), dict(l2_normalize=True, quantize=False),
            dict(l2_normalize=True, quantize=True)]
        for configuration in option_sets:
            options_type = vision.ImageClassifierOptions if task_name == 'classifier' else vision.ImageEmbedderOptions
            options = options_type(base_options=base, **configuration)
            with factory(options) as task:
                for kind in ['rgb', 'rgba', 'file', 'blank', 'rotated', 'roi']:
                    image = image_for(kind)
                    region = dict(left=0.15, top=0.1, right=0.85, bottom=0.9) if kind == 'roi' else None
                    rotation = 90 if kind == 'rotated' else 0
                    processing = ImageProcessingOptions(rotation_degrees=rotation,
                        region_of_interest=rect.RectF(**region) if region else None)
                    result = task.classify(image, processing) if task_name == 'classifier' else task.embed(image, processing)
                    case = dict(task=task_name, input=kind, width=image.width, height=image.height,
                                rotation_degrees=rotation, region=region, options=configuration,
                                result=dataclasses.asdict(result))
                    if kind == 'file':
                        case.update(file='landmark-ex1.jpg', sha256=digest(FIXTURES / 'landmark-ex1.jpg'))
                    elif kind != 'blank':
                        case.update(raw=raw.name, sha256=digest(raw))
                    cases.append(case)
                    print(task_name, configuration, kind, flush=True)
            options.running_mode = vision.RunningMode.VIDEO
            with factory(options) as task:
                for index, kind in enumerate(['rgb', 'blank', 'rgb']):
                    image = image_for(kind)
                    timestamp = index * 33
                    result = task.classify_for_video(image, timestamp) if task_name == 'classifier' else task.embed_for_video(image, timestamp)
                    cases.append(dict(task=task_name, input=kind, width=image.width, height=image.height,
                        rotation_degrees=0, region=None, timestamp_ms=timestamp, options=configuration,
                        raw=raw.name, sha256=digest(raw), result=dataclasses.asdict(result)))
    args.output_dir.mkdir(parents=True, exist_ok=True)
    suffix = '_gpu' if args.delegate == 'gpu' else ''
    (args.output_dir / f'official{suffix}_reference.json').write_text(reference_json(dict(
        runtime=RUNTIME, source_revision=SOURCE_REVISION,
        library_sha256=LIBRARY_SHA256, delegate=args.delegate.upper(),
        platform=f'{platform.system()} {platform.machine()}',
        models={key: sha for key, (_, sha) in MODELS.items()}, cases=cases),
        allow_nan=False, default=lambda value: value.tolist()) + '\n')


if __name__ == '__main__':
    main()

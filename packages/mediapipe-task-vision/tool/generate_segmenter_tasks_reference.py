"""Independent Image/Interactive Segmenter outputs from the official wheel."""
import argparse
import hashlib
import json
from pathlib import Path
import platform

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision.core.image_processing_options import ImageProcessingOptions
from official_face_runtime import (LIBRARY_NAME, LIBRARY_SHA256, RUNTIME,
                                   SOURCE_REVISION, VERSION)
from model_pins import model_sha256  # noqa: E402  (core/tool, via official_face_runtime)
from tool_helpers import digest, reference_json  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'test/fixtures/face_detection'
MODELS = {
    'image': ('deeplab_v3.tflite',
        model_sha256('deeplab_v3.tflite')),
}
# Coarse views of each file-input mask, for runtimes whose bytes differ from
# this wheel's: the mobile SDKs and the browser decode the JPEG themselves and
# run other builds. (columns, rows) of cell means for confidence masks that
# reach 0.5 somewhere, and of cell-centre classes for category masks.
CONFIDENCE_GRID = (16, 12)
CATEGORY_GRID = (32, 24)


def mask_array(mask, float32):
    if float32:
        # TODO: Re-test this 1.0.0 workaround on the pinned 1.1.0 wheel and
        # remove it if the direct copy passes.
        # In 1.0.0, float32's contiguous-copy path calls the uint8 ImageFrame
        # overload and aborts for padded rows. Scalar access is safe on both.
        return mask.numpy_view().copy() if mask.is_contiguous() else np.asarray(
            [[mask[y, x] for x in range(mask.width)] for y in range(mask.height)],
            dtype=np.float32)
    return mask.numpy_view().copy()


def mask_output(mask, float32):
    data = mask_array(mask, float32)
    # The same native library fills both sides on this host, so the exact bytes
    # are comparable; the summary only makes a mismatch readable.
    return dict(width=mask.width, height=mask.height,
                sha256=hashlib.sha256(data.tobytes()).hexdigest(),
                minimum=float(data.min()), maximum=float(data.max()),
                # Accumulate in float64 so the summary matches a Dart sum.
                mean=float(data.mean(dtype=np.float64)))


def result_output(result):
    masks = getattr(result, 'confidence_masks', None)
    category = getattr(result, 'category_mask', None)
    return dict(
        confidence_masks=None if masks is None else [mask_output(v, True) for v in masks],
        category_mask=None if category is None else mask_output(category, False))


def coarse_output(result):
    output = {}
    masks = getattr(result, 'confidence_masks', None)
    if masks is not None:
        columns, rows = CONFIDENCE_GRID
        grids = {}
        for index, mask in enumerate(masks):
            data = mask_array(mask, True).reshape(mask.height, mask.width)
            if data.max() < 0.5:
                continue
            grids[str(index)] = [
                [round(float(data[r * mask.height // rows:(r + 1) * mask.height // rows,
                                  c * mask.width // columns:(c + 1) * mask.width // columns]
                             .mean(dtype=np.float64)), 4) for c in range(columns)]
                for r in range(rows)]
        output['confidence_grids'] = grids
    category = getattr(result, 'category_mask', None)
    if category is not None:
        data = mask_array(category, False).reshape(category.height, category.width)
        columns, rows = CATEGORY_GRID
        output['category_grid'] = [
            [int(data[(2 * r + 1) * category.height // (2 * rows),
                      (2 * c + 1) * category.width // (2 * columns)]) for c in range(columns)]
            for r in range(rows)]
        values, counts = np.unique(data, return_counts=True)
        output['category_shares'] = {str(int(v)): round(int(n) / data.size, 6)
                                     for v, n in zip(values, counts)}
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--delegate', choices=['cpu', 'gpu'], default='cpu')
    parser.add_argument('--output-dir', type=Path,
                        default=ROOT / 'test/fixtures/segmenter_tasks')
    args = parser.parse_args()
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

    def record(task_name, kind, image, configuration, result, **extra):
        case = dict(task=task_name, input=kind, width=image.width, height=image.height,
                    options=configuration, result=result_output(result), **extra)
        if kind == 'file':
            case.update(file='landmark-ex1.jpg', sha256=digest(FIXTURES / 'landmark-ex1.jpg'),
                        coarse=coarse_output(result))
        elif kind != 'blank':
            case.update(raw=raw.name, sha256=digest(raw))
        cases.append(case)
        print(task_name, configuration, kind, extra, flush=True)

    masks_only = dict(output_confidence_masks=True, output_category_mask=False)
    category_only = dict(output_confidence_masks=False, output_category_mask=True)
    both = dict(output_confidence_masks=True, output_category_mask=True)

    base = mp.tasks.BaseOptions(
        model_asset_path=str(ROOT / 'models' / MODELS['image'][0]), delegate=delegate)
    for configuration in [masks_only, category_only, both]:
        options = vision.ImageSegmenterOptions(base_options=base, **configuration)
        with vision.ImageSegmenter.create_from_options(options) as task:
            # Both tasks reject a region of interest: the official API raises
            # "This task doesn't support region-of-interest."
            for kind in ['rgb', 'rgba', 'file', 'blank', 'rotated']:
                image = image_for(kind)
                rotation = 90 if kind == 'rotated' else 0
                processing = ImageProcessingOptions(rotation_degrees=rotation)
                record('image', kind, image, configuration, task.segment(image, processing),
                       rotation_degrees=rotation, timestamp_ms=None)
        if args.delegate == 'gpu':
            # TODO: Re-test this 1.0.0 workaround on the pinned 1.1.0 wheel and
            # generate the GPU VIDEO references if it no longer aborts.
            # Google's 1.0.0 macOS Metal path aborts in VIDEO mode on the
            # third frame with both mask kinds ("unsupported ImageFrame
            # format: 1" in gpu_buffer_storage_cv_pixel_buffer.cc). GPU
            # references cover Image Segmenter's IMAGE mode only.
            continue
        options.running_mode = vision.RunningMode.VIDEO
        with vision.ImageSegmenter.create_from_options(options) as task:
            for index, kind in enumerate(['rgb', 'blank', 'rgb']):
                image = image_for(kind)
                record('image', kind, image, configuration,
                       task.segment_for_video(image, index * 33),
                       rotation_degrees=0, timestamp_ms=index * 33)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    suffix = '_gpu' if args.delegate == 'gpu' else ''
    (args.output_dir / f'official{suffix}_reference.json').write_text(reference_json(dict(
        runtime=RUNTIME, source_revision=SOURCE_REVISION,
        library_sha256=LIBRARY_SHA256, delegate=args.delegate.upper(),
        platform=f'{platform.system()} {platform.machine()}',
        models={key: sha for key, (_, sha) in MODELS.items()}, cases=cases),
        allow_nan=False) + '\n')


if __name__ == '__main__':
    main()

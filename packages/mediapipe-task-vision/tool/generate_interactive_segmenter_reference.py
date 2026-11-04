"""Generate masks and ABI facts through Google's unmodified Python API.

It runs Google's wheel pinned for this host (core's tool/official_wheels.py).
The checked-in fixtures come from the macOS arm64 wheel. The Linux x64 desktop
job regenerates them in place with the pinned Linux wheel, because CPU results
drift between hosts. --python-package-root may point at an extracted,
checksum-verified copy of that wheel.
Ordinary Dart tests need neither Python nor network access for their fixtures.
"""
import argparse
import ctypes
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import sys
import time

from official_face_runtime import LIBRARY_NAME, LIBRARY_SHA256, RUNTIME, VERSION
from model_pins import model_sha256  # core's tool/, which the import above adds
from tool_helpers import reference_json  # noqa: E402

PACKAGE = Path(__file__).resolve().parents[1]
# The model pin the package itself uses (VisionModels.interactiveSegmenter).
MODEL_SHA256 = model_sha256('interactive_segmentation.task')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-package-root', type=Path)
    args = parser.parse_args()
    if args.python_package_root:
        sys.path.insert(0, str(args.python_package_root.resolve()))
    os.environ.setdefault('MPLCONFIGDIR', str(PACKAGE / 'build/matplotlib'))
    import mediapipe as mp
    import numpy as np
    from mediapipe.tasks.python.vision import interactive_segmenter as api
    from mediapipe.tasks.python.core.base_options_c import MpBaseOptionsC

    assert mp.__version__ == VERSION, mp.__version__
    host = (platform.system(), platform.machine().lower())
    if host not in (('Darwin', 'arm64'), ('Linux', 'x86_64'), ('Linux', 'amd64')):
        raise SystemExit('The stateful API is validated on macOS arm64 and Linux x64.')
    library, library_sha256 = LIBRARY_NAME, LIBRARY_SHA256
    library = Path(mp.__file__).parent / 'tasks/c' / library
    assert digest(library.read_bytes()) == library_sha256
    model = PACKAGE / 'models/interactive_segmentation.task'
    assert digest(model.read_bytes()) == MODEL_SHA256
    fixtures = PACKAGE / 'test/fixtures/interactive_segmentation'
    photo = fixtures / 'cats_and_dogs.jpg'
    source = mp.Image.create_from_file(str(photo))
    # Small odd-width input for exact buffer/stride comparisons across wrappers.
    pixels = np.ascontiguousarray(source.numpy_view()[::4, ::4, :3][:, :299])
    (fixtures / 'animals-299x150.rgb').write_bytes(pixels.tobytes())
    raw = mp.Image(image_format=mp.ImageFormat.SRGB, data=pixels)
    rgba = mp.Image(image_format=mp.ImageFormat.SRGBA, data=np.concatenate(
        [pixels, np.full((*pixels.shape[:2], 1), 255, dtype=np.uint8)], axis=2))
    blank = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.zeros_like(pixels))

    def stroke(mode, points, completed=True):
        return {'brush_mode': mode, 'points': points, 'is_completed': completed}
    cat = stroke('positive', [[.27, .8]])
    dog = stroke('positive', [[.66, .55]])
    partial = stroke('positive', [[.66, .55], [.65, .65]], False)
    negative = stroke('negative', [[.42, .6]])
    negative_partial = stroke('negative', [[.42, .6]], False)
    lasso = stroke('lasso', [[.52, .2], [.78, .2], [.78, .98], [.52, .98], [.52, .2]])
    lasso_open = stroke('lasso', [[.52, .2], [.78, .2], [.78, .98], [.52, .98]])
    lasso_corners = stroke('lasso', [[.52, .2], [.78, .98]])
    # Strokes as the gallery's editor sends them: an Exclude drag down the
    # dog (in progress while drawn), a lasso before the pointer lifts, and
    # mixed histories. The drag removes most of the dog, so a dropped or
    # misread Exclude stroke misses by far more than any tolerance.
    negative_drag = stroke('negative', [[.6, round(.25 + .07 * i, 2)] for i in range(11)])
    negative_drag_partial = stroke('negative', negative_drag['points'], False)
    lasso_unfinished = stroke('lasso', lasso_open['points'], False)
    across = stroke('negative', [[round(.55 + .025 * i, 3), .45] for i in range(11)])
    second_lasso = stroke('lasso', [[.05, .3], [.35, .95]])
    scenarios = [
        ('file-cat', 'file', True, [cat]),
        ('raw-dog', 'rgb', True, [dog]),
        ('raw-repeat', 'rgb', False, [dog]),
        ('raw-partial', 'rgb', False, [partial]),
        ('raw-two-positive', 'rgb', False, [dog, cat]),
        ('raw-negative', 'rgb', False, [dog, negative]),
        ('raw-lasso', 'rgb', False, [lasso]),
        # Google's graph reads a lasso as the bounding box of its points: the
        # open outline and the two opposite corners give the rectangle's mask,
        # and an unfinished Exclude stroke reads as the finished one. Cases
        # with the same mask share one file, so these cost no fixture bytes.
        ('raw-lasso-open', 'rgb', False, [lasso_open]),
        ('raw-lasso-corners', 'rgb', False, [lasso_corners]),
        ('raw-negative-partial', 'rgb', False, [dog, negative_partial]),
        ('raw-negative-drag', 'rgb', False, [dog, negative_drag]),
        ('raw-negative-drag-partial', 'rgb', False, [dog, negative_drag_partial]),
        # The completed flag only changes a lasso's mask: this case is the
        # one that shows a wrapper passes it through.
        ('raw-lasso-unfinished', 'rgb', False, [lasso_unfinished]),
        ('raw-lasso-negative', 'rgb', False, [lasso, across]),
        ('raw-two-lassos', 'rgb', False, [lasso, second_lasso]),
        ('raw-dog-lasso-negative', 'rgb', False, [dog, lasso, across]),
        ('raw-undo', 'rgb', False, [dog]),
        ('rgba-cat', 'rgba', True, [cat]),
        ('blank', 'blank', True, [dog]),
        ('replaced-image', 'rgb', True, [dog]),
    ]
    images = {'file': source, 'rgb': raw, 'rgba': rgba, 'blank': blank}
    report = {'runtime': RUNTIME, 'delegate': 'CPU',
              'library_sha256': library_sha256, 'model_sha256': MODEL_SHA256,
              'image': {'file': photo.name, 'sha256': digest(photo.read_bytes()),
                        'source': 'https://storage.googleapis.com/mediapipe-assets/cats_and_dogs.jpg'},
              'raw': {'file': 'animals-299x150.rgb', 'sha256': digest(pixels.tobytes()),
                      'width': raw.width, 'height': raw.height,
                      'derivation': 'Official JPEG RGB decode, [::4, ::4, :3][:, :299]'},
              'cases': []}
    options = api.InteractiveSegmenterOptions(mp.tasks.BaseOptions(
        model_asset_path=str(model), delegate=mp.tasks.BaseOptions.Delegate.CPU))
    written = {}
    masks = {}

    def native(strokes):
        return [api.Stroke(
            getattr(api.BrushMode, s['brush_mode'].upper()),
            [api.StrokePoint(*p) for p in s['points']], s['is_completed']) for s in strokes]

    def grid(mask, columns=16, rows=8):
        """Cell means on a columns x rows grid, as the gallery reduces a mask."""
        height, width = mask.shape[:2]
        return [[float(mask[r * height // rows:(r + 1) * height // rows,
                            c * width // columns:(c + 1) * width // columns].mean())
                 for c in range(columns)] for r in range(rows)]

    with api.InteractiveSegmenter.create_from_options(options) as task:
        for name, kind, set_image, strokes in scenarios:
            image = images[kind]
            t = time.perf_counter()
            if set_image:
                task.set_image(image)
            set_ms = (time.perf_counter() - t) * 1000 if set_image else None
            native_strokes = native(strokes)
            t = time.perf_counter()
            result = task.segment(native_strokes)
            mask = np.ascontiguousarray(result.numpy_view(), dtype='<f4')
            assert mask.shape == (image.height, image.width, 1)
            assert np.isfinite(mask).all() and mask.min() >= 0 and mask.max() <= 1
            data = mask.tobytes()
            masks[name] = mask.copy()  # numpy_view() is reused by later results
            # Cases with the same mask share the first one's file.
            filename = written.setdefault(digest(data), f'{name}.f32.gz')
            if filename == f'{name}.f32.gz':
                (fixtures / filename).write_bytes(gzip.compress(data, mtime=0))
            report['cases'].append({'name': name, 'input': kind, 'set_image': set_image,
                'strokes': strokes, 'width': image.width, 'height': image.height,
                'mask': filename, 'sha256': digest(data),
                'foreground_pixels': int((mask > .5).sum()), 'mean': float(mask.mean()),
                'set_image_ms': set_ms, 'segment_and_copy_ms': (time.perf_counter()-t)*1000})
            print(name, report['cases'][-1]['foreground_pixels'], flush=True)

        def differs(a, b):
            return float(np.abs(masks[a] - masks[b]).max()) > .5

        # Each stroke the cases add must change the mask, or a wrapper that
        # dropped or misread it would still match.
        assert differs('raw-dog', 'raw-negative-drag')
        assert not differs('raw-negative-drag', 'raw-negative-drag-partial')
        assert differs('raw-lasso', 'raw-lasso-unfinished')
        assert differs('raw-lasso', 'raw-lasso-negative')
        assert differs('raw-lasso', 'raw-two-lassos')
        assert differs('raw-lasso-negative', 'raw-dog-lasso-negative')
        # Phones and browsers compare Exclude and Lasso on the whole photo with
        # these reductions, as they compare Include with file-cat's mask:
        # cell means on a 16 x 8 grid, the mean and the share above 0.5. The
        # masks themselves are not stored.
        task.set_image(source)
        dog_grid = np.array(grid(task.segment(native([dog])).numpy_view()))
        report['summaries'] = []
        for name, strokes in [('file-dog-negative-drag', [dog, negative_drag]),
                              ('file-lasso', [lasso]),
                              ('file-lasso-corners', [lasso_corners])]:
            mask = np.ascontiguousarray(task.segment(native(strokes)).numpy_view(), dtype='<f4')
            if name == 'file-dog-negative-drag':
                # Phones allow 0.02 of mean cell error: dropping the Exclude
                # stroke must miss by well over that.
                assert np.abs(np.array(grid(mask)) - dog_grid).mean() > .05
            assert mask.shape == (source.height, source.width, 1)
            report['summaries'].append({
                'name': name, 'input': 'file', 'strokes': strokes,
                'width': source.width, 'height': source.height,
                'grid': grid(mask), 'mean': float(mask.mean()),
                'foreground': float((mask > .5).mean()), 'sha256': digest(mask.tobytes())})
            print(name, report['summaries'][-1]['foreground'], flush=True)
    report['abi'] = {
        cls.__name__: {'size': ctypes.sizeof(cls), 'alignment': ctypes.alignment(cls),
                      'offsets': {f[0]: getattr(cls, f[0]).offset for f in cls._fields_}}
        for cls in (MpBaseOptionsC, api.InteractiveSegmenterOptionsC, api.MpStrokePointC,
                    api.MpStrokeC, api.MpStrokesC)}
    (fixtures / 'official_reference.json').write_text(reference_json(report) + '\n')


if __name__ == '__main__':
    main()

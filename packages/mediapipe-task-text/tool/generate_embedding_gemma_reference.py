"""Capture EmbeddingGemma outputs from Google's unmodified Python API on this host.

Runs Google's wheel pinned for this host (core's tool/official_wheels.py): on
macOS arm64 the 1.0.0 wheel the engine was repackaged from (pass its extracted
site-packages via --python-package-root, or run with an interpreter that has it
installed), on Linux x64 and Windows x64 the wheel whose library core bundles.
Writes the checked-in fixture unless --output names another file.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import sys
import time

PACKAGE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PACKAGE.parent / 'mediapipe-core/tool'))
from official_wheels import host_runtime  # noqa: E402
from model_pins import model_sha256  # noqa: E402
from tool_helpers import reference_json  # noqa: E402
MODEL_SHA256 = model_sha256('embedding_gemma.task')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-package-root', type=Path)
    parser.add_argument('--output', type=Path,
                        default=PACKAGE / 'test/fixtures/embedding_gemma/official_reference.json')
    args = parser.parse_args()
    if args.python_package_root:
        sys.path.insert(0, str(args.python_package_root.resolve()))
    os.environ.setdefault('MPLCONFIGDIR', str(PACKAGE / 'build/matplotlib'))
    import mediapipe as mp
    import numpy as np
    from official_embedding_layout import use_header_embedding_layout
    use_header_embedding_layout('text')
    from mediapipe.tasks.python.text import text_embedder as api
    from mediapipe.tasks.python.core.base_options_c import MpBaseOptionsC
    from mediapipe.tasks.python.components.containers.embedding_result_c import (
        MpEmbeddingC, MpEmbeddingResultC)

    runtime = host_runtime()
    assert mp.__version__ == runtime['version'], mp.__version__
    library = Path(mp.__file__).parent / 'tasks/c' / runtime['library']
    assert hashlib.sha256(library.read_bytes()).hexdigest() == runtime['library_sha256']
    model = PACKAGE / 'models/embedding_gemma.task'
    assert hashlib.sha256(model.read_bytes()).hexdigest() == MODEL_SHA256
    cases = [
        ('default', 'A cat is sleeping on the sofa.', None),
        ('similarity-cat', 'A cat is sleeping on the sofa.', ('SEMANTIC_SIMILARITY', None, 'QUERY')),
        ('similarity-related', 'A kitten is resting on a couch.', ('SEMANTIC_SIMILARITY', None, 'QUERY')),
        ('similarity-unrelated', 'The database migration added three indexes.', ('SEMANTIC_SIMILARITY', None, 'QUERY')),
        ('retrieval-query', 'How do I grow tomatoes?', ('RETRIEVAL_QUERY', None, 'QUERY')),
        ('retrieval-document', 'Plant tomatoes in a sunny spot and water regularly.', ('RETRIEVAL_DOCUMENT', 'Growing tomatoes', 'DOCUMENT')),
        ('classification', 'This was a wonderful meal.', ('CLASSIFICATION', None, 'QUERY')),
        ('clustering', 'The train arrives at noon.', ('CLUSTERING', None, 'QUERY')),
        ('question', 'What is the capital of Canada?', ('QUESTION_ANSWERING', None, 'QUERY')),
        ('answer', 'Ottawa is the capital of Canada.', ('QUESTION_ANSWERING', 'Canada', 'DOCUMENT')),
        ('fact', 'Ottawa is the capital of Canada.', ('FACT_CHECKING', None, 'QUERY')),
        ('code', 'Sort a list of integers.', ('CODE_RETRIEVAL', None, 'QUERY')),
        ('unicode', 'Le café est délicieux. 猫が眠っています。 🐈', ('SEMANTIC_SIMILARITY', None, 'QUERY')),
        ('empty', '', None),
        ('long', 'A cat sleeps peacefully. ' * 80, ('SEMANTIC_SIMILARITY', None, 'QUERY')),
    ]
    report = {'runtime': 'mediapipe==' + runtime['version'], 'delegate': 'CPU',
              'library_sha256': runtime['library_sha256'], 'model_sha256': MODEL_SHA256,
              'model_url': 'https://storage.googleapis.com/mediapipe-models/text_embedder/embedding_gemma/int4int8/1/embedding_gemma.task',
              'machine': platform.machine(), 'os': platform.platform(), 'cases': []}
    for quantize, normalize in [(False, False), (True, True)]:
        options = api.TextEmbedderOptions(mp.tasks.BaseOptions(
            model_asset_path=str(model), delegate=mp.tasks.BaseOptions.Delegate.CPU),
            quantize=quantize, l2_normalize=normalize)
        start = time.perf_counter()
        with api.TextEmbedder.create_from_options(options) as task:
            print('created', quantize, (time.perf_counter() - start) * 1000, flush=True)
            for name, text, context in (cases[:2] if quantize else cases):
                native_context = None if context is None else api.TextFormatContext(
                    getattr(api.EmbeddingType, context[0]), context[1], getattr(api.TextRole, context[2]))
                start = time.perf_counter()
                result = task.embed(text, native_context)
                elapsed = (time.perf_counter() - start) * 1000
                embeddings = []
                for embedding in result.embeddings:
                    values = np.asarray(embedding.embedding)
                    assert len(values) == 768 and np.isfinite(values).all()
                    embeddings.append({'values': values.tolist(), 'head_index': embedding.head_index,
                                       'head_name': embedding.head_name})
                report['cases'].append({'name': name + ('-quantized' if quantize else ''),
                    'text': text, 'context': None if context is None else {
                        'task_type': context[0], 'title': context[1], 'role': context[2]},
                    'quantize': quantize, 'l2_normalize': normalize, 'ms': elapsed,
                    'embeddings': embeddings})
                print(name, round(elapsed, 2), flush=True)
    report['abi'] = {
        cls.__name__: {'size': ctypes.sizeof(cls), 'alignment': ctypes.alignment(cls),
                      'offsets': {f[0]: getattr(cls, f[0]).offset for f in cls._fields_}}
        for cls in (MpBaseOptionsC, api._MpEmbedderOptionsC, api._MpTextEmbedderOptionsC,
                    api._MpTextFormatContextC, MpEmbeddingC, MpEmbeddingResultC)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(reference_json(report) + '\n')
    print(args.output, flush=True)


if __name__ == '__main__':
    main()

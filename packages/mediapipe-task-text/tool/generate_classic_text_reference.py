"""Capture BERT, USE and language outputs from Google's runtime pinned for this host."""
import argparse
import ctypes
import dataclasses
import hashlib
import json
import os
from pathlib import Path
import platform
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'mediapipe-core/tool'))
from official_embedding_layout import use_header_embedding_layout  # noqa: E402
from official_wheels import MACOS, host_runtime  # noqa: E402
from tool_helpers import reference_json  # noqa: E402
from model_pins import model_sha256  # noqa: E402

PACKAGE = Path(__file__).resolve().parents[1]
# The checked-in baseline's library: Google's macOS arm64 build core bundles.
LIBRARY_SHA256 = MACOS['library_sha256']
MODELS = {
    'classifier': ('bert_classifier.tflite', model_sha256('bert_classifier.tflite')),
    'embedder': ('universal_sentence_encoder.tflite', model_sha256('universal_sentence_encoder.tflite')),
    'language': ('language_detector.tflite', model_sha256('language_detector.tflite')),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-package-root', type=Path)
    parser.add_argument('--output', type=Path,
                        default=PACKAGE / 'test/fixtures/classic_text/official_reference.json')
    args = parser.parse_args()
    if args.python_package_root:
        sys.path.insert(0, str(args.python_package_root.resolve()))
    os.environ.setdefault('MPLCONFIGDIR', str(PACKAGE / 'build/matplotlib'))
    import mediapipe as mp
    use_header_embedding_layout('text')
    from mediapipe.tasks.python.text import text_classifier as classifier
    from mediapipe.tasks.python.text import text_embedder as embedder
    from mediapipe.tasks.python.text import language_detector as language
    from mediapipe.tasks.python.components.processors.classifier_options_c import MpClassifierOptionsC
    from mediapipe.tasks.python.components.containers.classification_result_c import MpClassificationResultC, MpClassificationsC
    from mediapipe.tasks.python.components.containers.category_c import MpCategoryC
    from mediapipe.tasks.python.components.containers.embedding_result_c import MpEmbeddingResultC, MpEmbeddingC
    runtime = host_runtime()
    assert mp.__version__ == runtime['version']
    library = Path(mp.__file__).parent / 'tasks/c' / runtime['library']
    assert hashlib.sha256(library.read_bytes()).hexdigest() == runtime['library_sha256']
    host = ({'macos': platform.mac_ver()[0]} if platform.system() == 'Darwin'
            else {'os': platform.platform()})
    report = {'runtime': 'mediapipe==' + runtime['version'], 'delegate': 'CPU',
              'library_sha256': runtime['library_sha256'], **host,
              'models': {}, 'cases': [], 'creation_errors': [], 'lifecycle_sequences': {}}
    for name, (file, sha) in MODELS.items():
        model = PACKAGE / 'models' / file
        assert hashlib.sha256(model.read_bytes()).hexdigest() == sha
        report['models'][name] = {'file': file, 'sha256': sha}
    specs = [
        ('classifier', classifier.TextClassifierOptions, classifier.TextClassifier, 'classify', [
            ('positive', 'Hello, world!', {}),
            ('negative', 'This was a terrible movie. I hated every minute.', {}),
            ('unicode', 'The café was wonderful — I loved it!', {}),
            ('empty', '', {}),
            ('allow', 'Hello, world!', {'category_allowlist': ['positive', 'unknown', 'positive']}),
            ('deny', 'Hello, world!', {'category_denylist': ['positive']}),
            ('top', 'Hello, world!', {'max_results': 1}),
            ('threshold', 'Hello, world!', {'score_threshold': 1.0}),
            ('locale', 'Hello, world!', {'display_names_locale': 'fr'}),
        ]),
        ('embedder', embedder.TextEmbedderOptions, embedder.TextEmbedder, 'embed', [
            ('greeting', 'Hello, world!', {}),
            ('related', 'Hello there!', {}),
            ('different', 'The spacecraft landed on Mars.', {}),
            ('unicode', 'Le café est délicieux. こんにちは', {}),
            ('empty', '', {}),
            ('normalized', 'Hello, world!', {'l2_normalize': True}),
            ('quantized', 'Hello, world!', {'l2_normalize': True, 'quantize': True}),
            ('quantized-related', 'Hello there!', {'l2_normalize': True, 'quantize': True}),
        ]),
        ('language', language.LanguageDetectorOptions, language.LanguageDetector, 'detect', [
            ('english', 'Hello, world!', {}),
            ('spanish', 'Quiero agua, por favor.', {}),
            ('japanese', 'こんにちは、元気ですか？', {}),
            ('french', 'Bonjour, comment allez-vous aujourd’hui ?', {}),
            ('empty', '', {}),
            ('top', 'Hello, world!', {'max_results': 2}),
            ('allow', 'Hello, world!', {'category_allowlist': ['en', 'fr']}),
            ('deny', 'Hello, world!', {'category_denylist': ['en'], 'max_results': 2}),
            ('threshold', 'Hello, world!', {'score_threshold': 1.0}),
        ]),
    ]
    embeddings = {}
    def result_json(result, task_name):
        if task_name != 'embedder':
            return dataclasses.asdict(result)
        return {'timestamp_ms': result.timestamp_ms, 'embeddings': [
            {'values': e.embedding.tolist(), 'quantized': e.embedding.dtype.name == 'uint8',
             'head_index': e.head_index, 'head_name': e.head_name} for e in result.embeddings]}

    for task_name, options_class, task_class, method, cases in specs:
        model = PACKAGE / 'models' / MODELS[task_name][0]
        for name, text, config in cases:
            with task_class.create_from_options(options_class(
                    mp.tasks.BaseOptions(model_asset_path=str(model)), **config)) as task:
                result = getattr(task, method)(text)
                if task_name == 'embedder':
                    embeddings[name] = result.embeddings[0]
                value = result_json(result, task_name)
                report['cases'].append({'task': task_name, 'name': name, 'input': text,
                                        'options': config, 'result': value})
                print(task_name, name, flush=True)
        with task_class.create_from_options(options_class(
                mp.tasks.BaseOptions(model_asset_path=str(model)))) as task:
            report['lifecycle_sequences'][task_name] = [
                {'input': text, 'result': result_json(getattr(task, method)(text), task_name)}
                for text in ['Hello, world!', 'Quiero agua, por favor.'] * 2]
        if task_name != 'embedder':
            for config in ({'max_results': 0}, {'category_allowlist': ['en'], 'category_denylist': ['fr']}):
                try:
                    with task_class.create_from_options(options_class(
                            mp.tasks.BaseOptions(model_asset_path=str(model)), **config)):
                        raise AssertionError('Expected creation to fail')
                except ValueError as error:
                    report['creation_errors'].append({'task': task_name, 'options': config, 'error': str(error)})
    report['similarities'] = [{'a': a, 'b': b, 'value': embedder.TextEmbedder.cosine_similarity(embeddings[a], embeddings[b])}
                              for a, b in [('greeting', 'greeting'), ('greeting', 'related'), ('greeting', 'different'),
                                           ('quantized', 'quantized-related')]]
    report['abi'] = {cls.__name__: {
        'size': ctypes.sizeof(cls), 'alignment': ctypes.alignment(cls),
        'offsets': {f[0]: getattr(cls, f[0]).offset for f in cls._fields_}}
        for cls in (classifier.MpTextClassifierOptionsC, MpClassifierOptionsC, MpClassificationResultC,
                    MpClassificationsC, MpCategoryC, MpEmbeddingResultC, MpEmbeddingC,
                    language.MpLanguageDetectorOptionsC, language.MpLanguageDetectorPredictionC,
                    language.MpLanguageDetectorResultC)}
    target = args.output.resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(reference_json(report, ensure_ascii=False) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

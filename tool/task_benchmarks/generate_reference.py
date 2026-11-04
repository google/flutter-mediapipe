"""Generate the option/long-input matrix using unmodified MediaPipe: Google's macOS reference wheel.

This is separate from the existing fixtures, which remain unchanged. The Dart
runner checks these official outputs, including observed native errors. Timing
measurements are made by the Dart runner separately from reference generation.
"""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[2]
TEXT = ROOT / 'packages/mediapipe-task-text'
sys.path.insert(0, str(TEXT / 'tool'))
from probe_text_gpu import MODELS
sys.path.insert(0, str(ROOT / 'packages/mediapipe-core/tool'))
from official_wheels import MACOS  # noqa: E402  core's referenceWheels row for macOS
LIBRARY_SHA = MACOS['library_sha256']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-package-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--over-capacity-only', action='store_true')
    args = parser.parse_args()
    sys.path.insert(0, str(args.python_package_root.resolve()))
    os.environ.setdefault('MPLCONFIGDIR', str(TEXT / 'build/matplotlib'))
    import mediapipe as mp
    from mediapipe.tasks.python.text import text_embedder as embedding
    from mediapipe.tasks.python.text import text_proofreader as proofreader
    from mediapipe.tasks.python.text import text_summarizer as summarizer
    assert mp.__version__ == MACOS['version'], mp.__version__
    assert hashlib.sha256((Path(mp.__file__).parent / 'tasks/c/libmediapipe.dylib').read_bytes()).hexdigest() == LIBRARY_SHA
    for filename, digest in MODELS.values():
        assert hashlib.sha256((TEXT / 'models' / filename).read_bytes()).hexdigest() == digest
    report = {'runtime': MACOS['version'], 'library_sha256': LIBRARY_SHA,
              'models': {k: v[1] for k, v in MODELS.items()},
              'machine': platform.machine(), 'macos': platform.mac_ver()[0], 'cases': []}

    def base(task):
        return mp.tasks.BaseOptions(model_asset_path=str(TEXT / 'models' / MODELS[task][0]),
                                    delegate=mp.tasks.BaseOptions.Delegate.CPU)

    def record(task, name, text, options, run, context=None):
        entry = {'task': task, 'name': name, 'input': text, 'options': options, 'context': context}
        try:
            entry['output'] = run()
        except (ValueError, RuntimeError) as error:
            entry['error'] = str(error)
        report['cases'].append(entry)
        print(task, name, 'error' if 'error' in entry else 'ok', flush=True)
        return entry

    def stream_result(task, kind, text):
        terminal = threading.Event()
        events = []
        def callback(update, error):
            events.append((update, error))
            if error or update.done:
                terminal.set()
        submit = task.proofread_async if kind == 'proofreader' else task.summarize_async
        submit(text, callback)
        assert terminal.wait(60), 'Missing terminal streaming callback'
        errors = [error for _, error in events if error]
        if errors:
            assert len(errors) == 1
            raise RuntimeError(errors[0])
        assert sum(update.done for update, _ in events) == 1 and events[-1][0].done
        if kind == 'proofreader':
            return {'text': ''.join(update.proofread_text or '' for update, _ in events),
                    'corrections': [{'type': c.type.name.lower(), 'text': c.text}
                                    for c in events[-1][0].corrections]}
        return ''.join(update.summary or '' for update, _ in events)

    if args.over_capacity_only:
        task = embedding.TextEmbedder.create_from_options(embedding.TextEmbedderOptions(base('embedding')))
        text = 'cat ' * 600
        record('embedding', 'over-capacity', text, {'normalize': False, 'quantize': False},
               lambda: task.embed(text).embeddings[0].embedding.tolist())
        try:
            task.close()
        except RuntimeError as error:
            report['embedding_over_capacity_close_error'] = str(error)
        args.output.write_text(json.dumps(report))
        # The upstream Python wrapper may close the failed handle a second time
        # during destruction. Isolate this known failure and skip destructors.
        os._exit(0)

    existing = json.loads((TEXT / 'test/fixtures/embedding_gemma/official_reference.json').read_text())
    for normalize in [False, True]:
        for quantize in [False, True]:
            options = {'normalize': normalize, 'quantize': quantize}
            with embedding.TextEmbedder.create_from_options(embedding.TextEmbedderOptions(
                    base('embedding'), l2_normalize=normalize, quantize=quantize)) as task:
                for entry in existing['cases']:
                    if entry['quantize']:
                        continue
                    context = entry['context']
                    native = None if context is None else embedding.TextFormatContext(
                        getattr(embedding.EmbeddingType, context['task_type']), context['title'],
                        getattr(embedding.TextRole, context['role']))
                    record('embedding', entry['name'], entry['text'], options,
                           lambda: task.embed(entry['text'], native).embeddings[0].embedding.tolist(), context)
    short = 'The library will close at six today for maintenance and reopen tomorrow morning.'
    long_text = ('The library opened in 1985. It provides free classes, books, and internet access. '
                 'Renovations start on Monday and will take six weeks. During construction, '
                 'visitors can collect reserved books from the temporary desk at city hall. ') * 12
    for kind in ['proofreader', 'summarizer']:
        for mode in ([None] if kind == 'proofreader' else ['TLDR', 'KEYPOINTS']):
            for budget in [0, 64, 256, 1024, 4096, 8192]:
                options = {'budget': budget, 'mode': mode}
                if kind == 'proofreader':
                    task = proofreader.TextProofreader.create_from_options(
                        proofreader.TextProofreaderOptions(base(kind), max_num_tokens=budget))
                    def run(text):
                        result = task.proofread(text)
                        return {'text': result.proofread_text, 'corrections': [
                            {'type': c.type.name.lower(), 'text': c.text} for c in result.corrections]}
                else:
                    task = summarizer.TextSummarizer.create_from_options(summarizer.TextSummarizerOptions(
                        base(kind), mode=getattr(summarizer.Mode, mode), max_num_tokens=budget))
                    run = lambda text: task.summarize(text).summary
                with task:
                    for name, text in [('short', short), ('long', long_text)]:
                        entry = record(kind, name, text, options, lambda: run(text))
                        try:
                            entry['stream_output'] = stream_result(task, kind, text)
                        except (ValueError, RuntimeError) as error:
                            entry['stream_error'] = str(error)
    isolated = ROOT / 'build/task-benchmarks/over-capacity-reference.json'
    isolated.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, '-B', str(Path(__file__).resolve()),
                    '--python-package-root', str(args.python_package_root.resolve()),
                    '--output', str(isolated), '--over-capacity-only'],
                   check=True, timeout=30)
    failure = json.loads(isolated.read_text())
    report['cases'].extend(failure['cases'])
    report['embedding_over_capacity_close_error'] = failure.get('embedding_over_capacity_close_error')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(report, sort_keys=True).encode()
    args.output.write_bytes(gzip.compress(payload, mtime=0))
    print(args.output, hashlib.sha256(payload).hexdigest(), flush=True)


if __name__ == '__main__':
    main()

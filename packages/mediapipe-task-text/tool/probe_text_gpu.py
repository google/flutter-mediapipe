"""Probe CPU/GPU requests in isolated processes using Google's pinned runtime.

Successful output alone does not establish GPU execution: retain native logs
and inspect backend selection before changing the package's supported delegates.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

PACKAGE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PACKAGE.parent / 'mediapipe-core/tool'))
from model_pins import model_sha256  # noqa: E402
from official_wheels import MACOS  # noqa: E402  core's referenceWheels row for macOS
LIBRARY_SHA = MACOS['library_sha256']
MODELS = {
    'embedding': ('embedding_gemma.task', model_sha256('embedding_gemma.task')),
    'proofreader': ('proofread_quant_200m.litertlm', model_sha256('proofread_quant_200m.litertlm')),
    'summarizer': ('summarization_quant_200m_2modes.litertlm', model_sha256('summarization_quant_200m_2modes.litertlm')),
}


def child(args):
    sys.path.insert(0, str(args.python_package_root.resolve()))
    os.environ.setdefault('MPLCONFIGDIR', str(PACKAGE / 'build/matplotlib'))
    import mediapipe as mp
    assert mp.__version__ == MACOS['version'], mp.__version__
    library = Path(mp.__file__).parent / 'tasks/c/libmediapipe.dylib'
    assert hashlib.sha256(library.read_bytes()).hexdigest() == LIBRARY_SHA
    filename, digest = MODELS[args.task]
    model = PACKAGE / 'models' / filename
    assert hashlib.sha256(model.read_bytes()).hexdigest() == digest
    base = mp.tasks.BaseOptions(
        model_asset_path=str(model),
        delegate=getattr(mp.tasks.BaseOptions.Delegate, args.delegate))
    print('PHASE create', flush=True)
    start = time.perf_counter()
    if args.task == 'embedding':
        from mediapipe.tasks.python.text import text_embedder as api
        task = api.TextEmbedder.create_from_options(api.TextEmbedderOptions(base))
        run = lambda: task.embed('A cat is sleeping on the sofa.').embeddings[0].embedding.tolist()
    elif args.task == 'proofreader':
        from mediapipe.tasks.python.text import text_proofreader as api
        task = api.TextProofreader.create_from_options(api.TextProofreaderOptions(base))
        run = lambda: str(task.proofread('She go to the store yesterday and buyed some apples.'))
    else:
        from mediapipe.tasks.python.text import text_summarizer as api
        task = api.TextSummarizer.create_from_options(api.TextSummarizerOptions(base))
        run = lambda: str(task.summarize('The library will close at six today for maintenance and reopen tomorrow morning.'))
    print('PHASE inference', flush=True)
    created_ms = (time.perf_counter() - start) * 1000
    results = []
    try:
        for _ in range(3):
            start = time.perf_counter()
            output = run()
            results.append({'ms': (time.perf_counter() - start) * 1000, 'output': output})
    finally:
        print('PHASE close', flush=True)
        task.close()
    print('RESULT ' + json.dumps({'created_ms': created_ms, 'results': results}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-package-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--task', choices=MODELS)
    parser.add_argument('--delegate', choices=['CPU', 'GPU'])
    args = parser.parse_args()
    if args.task:
        child(args)
        return
    assert platform.system() == 'Darwin' and platform.machine() == 'arm64'
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'runtime': MACOS['version'], 'library_sha256': LIBRARY_SHA,
              'macos': platform.mac_ver()[0], 'machine': platform.machine(),
              'python': platform.python_version(), 'probes': [],
              'note': 'Delegate requests are not proof of GPU execution; inspect native logs.'}
    for task in MODELS:
        for delegate in ['CPU', 'GPU']:
            command = [sys.executable, '-B', str(Path(__file__).resolve()),
                       '--python-package-root', str(args.python_package_root.resolve()),
                       '--output', str(args.output.resolve()), '--task', task,
                       '--delegate', delegate]
            print(task, delegate, flush=True)
            with (args.output / f'{task}-{delegate.lower()}.log').open('w') as log:
                try:
                    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                            timeout=args.timeout, check=False)
                    status = result.returncode
                except subprocess.TimeoutExpired:
                    status = 'timeout'
            lines = (args.output / f'{task}-{delegate.lower()}.log').read_text().splitlines()
            entry = {'task': task, 'requested_delegate': delegate, 'exit_code': status,
                     'model_sha256': MODELS[task][1],
                     'last_phase': next((line for line in reversed(lines) if line.startswith('PHASE ')), None)}
            for line in lines:
                if line.startswith('RESULT '):
                    entry['result'] = json.loads(line[7:])
            report['probes'].append(entry)
            (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
            print(task, delegate, status, entry['last_phase'], flush=True)
    if any(p['exit_code'] != 0 for p in report['probes'] if p['requested_delegate'] == 'CPU'):
        raise SystemExit('CPU control failed; GPU conclusions are invalid.')


if __name__ == '__main__':
    main()

"""Capture Google's Summarizer results, streams and ctypes layouts on this host.

Runs Google's wheel pinned for this host (core's tool/official_wheels.py) and
writes the checked-in fixture unless --output names another file.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import sys
import threading
import time

PACKAGE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PACKAGE.parent / 'mediapipe-core/tool'))
from official_wheels import host_runtime  # noqa: E402
from tool_helpers import reference_json  # noqa: E402
from model_pins import model_sha256  # noqa: E402
MODEL_SHA256 = model_sha256('summarization_quant_200m_2modes.litertlm')
MODEL_URL = 'https://storage.googleapis.com/mediapipe-models/text_summarizer/200m/1/summarization_quant_200m_2modes.litertlm'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-package-root', type=Path,
                        help='an extracted wheel to import instead of the installed one')
    parser.add_argument('--output', type=Path,
                        default=PACKAGE / 'test/fixtures/summarizer/official_reference.json')
    args = parser.parse_args()
    if args.python_package_root:
        sys.path.insert(0, str(args.python_package_root.resolve()))
    os.environ.setdefault('MPLCONFIGDIR', str(PACKAGE / 'build/matplotlib'))
    import mediapipe as mp
    from mediapipe.tasks.python.text import text_summarizer as api
    from mediapipe.tasks.python.core.base_options_c import MpBaseOptionsC
    runtime = host_runtime()
    assert mp.__version__ == runtime['version'], mp.__version__
    library = Path(mp.__file__).parent / 'tasks/c' / runtime['library']
    assert hashlib.sha256(library.read_bytes()).hexdigest() == runtime['library_sha256']
    model = PACKAGE / 'models/summarization_quant_200m_2modes.litertlm'
    assert hashlib.sha256(model.read_bytes()).hexdigest() == MODEL_SHA256
    cases = [
        ('meeting', 'The team met on Monday to plan the next app release. Maya will finish '
         'the camera interface by Thursday. Leo will investigate the startup crash and '
         'send a fix for review on Wednesday. Testing begins on Friday, and the release '
         'is scheduled for the following Tuesday if no critical bugs remain. The team '
         'decided to postpone the new settings screen until the next release.'),
        ('garden', 'A community garden opened beside the town library in April. Volunteers '
         'built twelve raised beds and planted tomatoes, carrots, and herbs. Rainwater '
         'collected from the library roof supplies most of the irrigation. Residents '
         'can join a Saturday workshop to learn composting and share tools. Half of '
         'the vegetables harvested this summer will be donated to the local food bank.'),
        ('unicode', 'María and André opened a café in Montréal last spring. They serve '
         'coffee and fresh pastries every morning. After customers requested more '
         'options, they added vegan sandwiches and extended their opening hours on '
         'weekends. They plan to hire two employees before the winter season.'),
        ('short', 'The library will close at six today for maintenance and reopen tomorrow morning.'),
        ('empty', ''),
    ]
    report = {'runtime': 'mediapipe==' + runtime['version'], 'delegate': 'CPU',
              'library_sha256': runtime['library_sha256'], 'model_sha256': MODEL_SHA256,
              'model_url': MODEL_URL, 'os': platform.platform(),
              'machine': platform.machine(), 'cases': [], 'errors': []}
    for mode in api.Mode:
        for limit in [None, 64]:
            options = api.TextSummarizerOptions(mp.tasks.BaseOptions(
                model_asset_path=str(model), delegate=mp.tasks.BaseOptions.Delegate.CPU),
                mode=mode, max_num_tokens=limit)
            with api.TextSummarizer.create_from_options(options) as task:
                for name, text in (cases if limit is None else cases[3:4]):
                    start = time.perf_counter()
                    try:
                        result = task.summarize(text)
                    except ValueError as error:
                        assert text == '', f'Unexpected failure: {error}'
                        terminal = threading.Event()
                        errors = []
                        def error_callback(update, message):
                            errors.append(message)
                            terminal.set()
                        try:
                            task.summarize_async(text, error_callback)
                        except ValueError as stream_error:
                            errors.append(str(stream_error))
                        else:
                            assert terminal.wait(60), 'No empty-input error callback'
                        assert errors == [str(error)], errors
                        report['errors'].append({'input': text, 'mode': mode.name,
                            'message': str(error), 'stream_message': errors[0]})
                        print(mode.name, 'empty input rejected:', error, flush=True)
                        continue
                    sync_ms = (time.perf_counter() - start) * 1000
                    events = []
                    done = threading.Event()
                    def callback(update, error):
                        events.append({'error': error} if error else
                                      {'chunk': update.summary, 'done': update.done})
                        if error or update.done: done.set()
                    start = time.perf_counter()
                    task.summarize_async(text, callback)
                    assert done.wait(60), 'No terminal callback'
                    stream_ms = (time.perf_counter() - start) * 1000
                    assert not any('error' in event for event in events), events
                    assert sum(e['done'] for e in events) == 1 and events[-1]['done']
                    # Google's streamed text can differ from its completed text
                    # for the same input: on its x86_64 1.0.0 wheels it does
                    # (upstream-issues.md UP-036). Both are recorded, and each
                    # path of the package is compared with its own.
                    streamed = ''.join(e['chunk'] or '' for e in events)
                    report['cases'].append({
                        'name': f'{mode.name.lower()}-{name}' + (f'-limit-{limit}' if limit else ''),
                        'input': text, 'mode': mode.name, 'max_num_tokens': limit,
                        'result': {'summary': result.summary, 'done': result.done},
                        'stream': events, 'stream_matches_result': streamed == (result.summary or ''),
                        'sync_ms': sync_ms, 'stream_ms': stream_ms})
                    print(mode.name, name, limit, round(sync_ms, 2), repr(result.summary), flush=True)
    report['abi'] = {cls.__name__: {
        'size': ctypes.sizeof(cls), 'alignment': ctypes.alignment(cls),
        'offsets': {f[0]: getattr(cls, f[0]).offset for f in cls._fields_}}
        for cls in (MpBaseOptionsC, api._MpTextSummarizerOptionsC,
                    api._MpTextSummarizerResultC, api._MpTextSummarizerStreamResultC)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(reference_json(report) + '\n')
    print(args.output, flush=True)


if __name__ == '__main__':
    main()

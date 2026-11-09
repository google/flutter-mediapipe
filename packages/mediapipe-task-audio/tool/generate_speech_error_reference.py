"""Capture what Google's speech tasks do with a model path that is no model.

Runs the official Python API from the checksum-pinned speech wheel for this
host, as generate_speech_reference.py does, and needs no model: each task is
created from a missing path, a directory and a file that is not a model, each
in a process of its own, because Google's library on Linux ends the process
for some of them. A case records Google's status and message, with the path
written as {path}, or that the process was aborted and Google's fatal log
line. The status differs by OS, so each desktop CI runner regenerates this
reference; test/fixtures/official_speech_error_reference.json is the macOS
arm64 one. Never derive expected values from the Dart implementation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile

from generate_audio_reference import FIXTURES, HOST_NAMES, PACKAGE

sys.path.insert(0, str(PACKAGE.parent / 'mediapipe-core/tool'))
from official_wheels import host_runtime  # noqa: E402
from tool_helpers import reference_json  # noqa: E402

# Each case: the file name and whether the path is missing, a directory or a
# file holding NOT_A_MODEL. A missing path is /nonexistent/<name>; the others
# sit in a temporary folder, under directory/ or file/. Google picks how to
# read a path that is not a file from its name, so the names are the pinned
# models' own, and the tests' first missing paths.
CASES = {
    'transcriber': {
        'missing': ('parakeet.litertlm', 'missing'),
        'missing-pinned-name': ('parakeet_tdt_0.6b_v3_5s_i8_stateful.litertlm', 'missing'),
        'directory': ('parakeet_tdt_0.6b_v3_5s_i8_stateful.litertlm', 'directory'),
        'not-a-model': ('parakeet_tdt_0.6b_v3_5s_i8_stateful.litertlm', 'file'),
    },
    'text_to_speech': {
        'missing': ('phonon.litertlm', 'missing'),
        'missing-kokoro': ('kokoro_int8_gpu_fp16.litertlm', 'missing'),
        'missing-pocket-tts': ('pocket_tts_en_int8.litertlm', 'missing'),
        'directory': ('phonon_int8.litertlm', 'directory'),
        'directory-kokoro': ('kokoro_int8_gpu_fp16.litertlm', 'directory'),
        'not-a-model': ('phonon_int8.litertlm', 'file'),
    },
}
# The bytes of the file that is not a model: Google quotes the first eight.
NOT_A_MODEL = 'not a model'
STATUS = re.compile(r'C API error \((\d+)\): (.*)', re.DOTALL)
# Google's fatal log line, from its message to the first double space.
FATAL = re.compile(r'^F\d{4} [^\]]*\] (.*?)(?:  |$)', re.MULTILINE)


def create(task, path):
    """Creates Google's [task] from [path] in this process and prints the
    outcome as JSON."""
    import mediapipe as mp
    from mediapipe.tasks.python.audio import audio_transcriber, text_to_speech

    base = mp.tasks.BaseOptions(model_asset_path=path)
    try:
        if task == 'transcriber':
            audio_transcriber.AudioTranscriber.create_from_options(
                audio_transcriber.AudioTranscriberOptions(base_options=base))
        else:
            text_to_speech.TextToSpeech.create_from_options(
                text_to_speech.TextToSpeechOptions(base_options=base, default_locale=None))
        outcome = {'created': True}
    except RuntimeError as error:
        match = STATUS.search(str(error))
        assert match, error
        outcome = {'status': int(match[1]), 'message': match[2]}
    print(json.dumps(outcome), flush=True)


def case(task, path):
    """Google's outcome for [task] from [path], in a child process."""
    result = subprocess.run([sys.executable, '-B', __file__, '--create', task, str(path)],
                            capture_output=True, text=True, encoding='utf-8',
                            errors='replace')
    if result.returncode == 0:
        outcome = json.loads(result.stdout.strip().splitlines()[-1])
        if 'message' in outcome:
            outcome['message'] = outcome['message'].replace(str(path), '{path}')
    else:
        # Google's fatal line, else the last one it wrote.
        fatal = FATAL.search(result.stderr)
        log = fatal[1] if fatal else (result.stderr.strip().splitlines() or [''])[-1]
        print(result.stderr[-2000:], flush=True)
        outcome = {'aborted': True, 'log': log.strip().replace(str(path), '{path}')}
    print(task, path, outcome, flush=True)
    return outcome


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', nargs=2, metavar=('TASK', 'PATH'), help=argparse.SUPPRESS)
    parser.add_argument('--output', type=Path,
                        default=FIXTURES / 'official_speech_error_reference.json')
    args = parser.parse_args()
    # Google's messages hold box-drawing characters; Windows defaults to cp1252.
    sys.stdout.reconfigure(encoding='utf-8')
    os.environ.setdefault('MPLCONFIGDIR', str(PACKAGE / 'build/matplotlib'))
    if args.create:
        create(*args.create)
        return
    import mediapipe as mp

    runtime = host_runtime('releaseReferenceWheels')
    name, version = HOST_NAMES[platform.system()], runtime['version']
    assert mp.__version__ == version, mp.__version__
    library = Path(mp.__file__).parent / 'tasks/c' / runtime['library']
    assert hashlib.sha256(library.read_bytes()).hexdigest() == runtime['library_sha256']
    cases = {}
    with tempfile.TemporaryDirectory() as root:
        for task, table in CASES.items():
            cases[task] = {}
            for key, (file, kind) in table.items():
                if kind == 'missing':
                    path = f'/nonexistent/{file}'
                else:
                    path = Path(root) / kind / file
                    path.parent.mkdir(exist_ok=True)
                    if kind == 'directory':
                        path.mkdir(exist_ok=True)
                    else:
                        path.write_bytes(NOT_A_MODEL.encode('ascii'))
                cases[task][key] = {'file': file, 'kind': kind, **case(task, path)}
    report = {
        'runtime': f'mediapipe=={version}',
        'source': f'official Python AudioTranscriber and TextToSpeech create, {name} wheel',
        'paths': '{path} is the model path the task was given: /nonexistent/<file> when '
                 'missing, else <file> in directory/ or file/ of a temporary folder',
        'not_a_model': NOT_A_MODEL,
        'cases': cases,
    }
    args.output.resolve().parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(reference_json(report, ensure_ascii=False) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

"""Generate independent speech references on the host running the tests.

Uses Google's checksum-pinned speech wheel for this host (core's
`releaseReferenceWheels`) and never rewrites the checked-in reference or
changes test tolerances. Set MEDIAPIPE_SPEECH_REFERENCE_DIR to the output
directory to test against it.
"""
import argparse
import json
from pathlib import Path
import platform
import subprocess
import sys

from generate_audio_reference import FIXTURES, PACKAGE
from official_wheels import host_runtime, pinned_venv
from tool_helpers import digest

REPO = PACKAGE.parents[1]
BASELINE = FIXTURES / 'official_speech_reference.json'
KOKORO_BASELINE = FIXTURES / 'official_kokoro_reference.json'
POCKET_TTS_BASELINE = FIXTURES / 'official_pocket_tts_reference.json'
POCKET_TTS_MODEL = PACKAGE / 'models/pocket_tts_en_int8.litertlm'
ERROR_BASELINE = FIXTURES / 'official_speech_error_reference.json'


def audio_difference(old, new):
    """The largest level difference between two synthesized results, or why
    they cannot be compared."""
    if (old['samples'], old['sample_rate_hz']) != (new['samples'], new['sample_rate_hz']):
        return 'length or rate differs'
    if [w[:3] for w in old['words']] != [w[:3] for w in new['words']]:
        return 'words differ'
    return max([abs(old['peak'] - new['peak']),
                *(abs(a - b) for a, b in zip(old['envelope'], new['envelope']))])


def differences(baseline, current):
    """Any change in the transcripts, and the largest level difference per
    synthesized case."""
    structural, levels = [], {}
    old, new = baseline['cases'], current['cases']
    for case in old['transcriber'].keys() | new['transcriber'].keys():
        left, right = old['transcriber'].get(case), new['transcriber'].get(case)
        if left is None or right is None or (left['calls'], left['finish']) != (
                right['calls'], right['finish']):
            structural.append(f'transcriber {case}: segments differ')
    left, right = old['text_to_speech'], new['text_to_speech']
    if left['voices'] != right['voices']:
        structural.append('voices differ')
    pairs = [(f'utterance {name}', left['utterances'][name], right['utterances'].get(name))
             for name in left['utterances']]
    pairs.append(('fast', left['fast'], right['fast']))
    if len(left['stream']['chunks']) != len(right['stream']['chunks']):
        structural.append('stream: chunk count differs')
    else:
        pairs += [(f'stream chunk {i}', a, b) for i, (a, b) in
                  enumerate(zip(left['stream']['chunks'], right['stream']['chunks']))]
    return compare(pairs, structural, levels)


def compare(pairs, structural, levels):
    for name, a, b in pairs:
        difference = 'missing' if b is None else audio_difference(a, b)
        if isinstance(difference, str):
            structural.append(f'{name}: {difference}')
        else:
            levels[name] = difference
    return {'maximum_level_error': levels, 'structural_differences': structural}


def kokoro_differences(baseline, current):
    """As differences, for Kokoro's reference."""
    structural, levels = [], {}
    left, right = baseline['cases']['text_to_speech'], current['cases']['text_to_speech']
    if left['voices'] != right['voices']:
        structural.append('voices differ')
    pairs = [(f'utterance {name}', left['utterances'][name], right['utterances'].get(name))
             for name in left['utterances']]
    pairs += [(f'default voice {name}', left['default_voice'][name],
               right['default_voice'].get(name))
              for name in ('inferred', 'voice_locale')]
    if left['default_voice']['en-US'] != right['default_voice']['en-US']:
        structural.append('default voice en-US: the error differs')
    return compare(pairs, structural, levels)


def error_differences(baseline, current):
    """The cases whose outcome on this host differs from the macOS one."""
    old, new = baseline['cases'], current['cases']
    return sorted(f'{task} {case}' for task in old.keys() | new.keys()
                  for case in old.get(task, {}).keys() | new.get(task, {}).keys()
                  if old.get(task, {}).get(case) != new.get(task, {}).get(case))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python', type=Path, help='Existing environment with the pinned wheel')
    parser.add_argument('--output-dir', type=Path, default=REPO / 'build/speech-reference')
    parser.add_argument('--errors-only', action='store_true',
                        help='Only the model-free error reference, for a runner without the models')
    args = parser.parse_args()
    # The log's end holds Google's box-drawing characters; Windows defaults to
    # cp1252.
    sys.stdout.reconfigure(encoding='utf-8')
    runtime = host_runtime('releaseReferenceWheels')
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'provenance.json'
    receipt.unlink(missing_ok=True)
    pocket_tts = output / POCKET_TTS_BASELINE.name
    pocket_tts.unlink(missing_ok=True)
    python = args.python
    if python is None:
        python = pinned_venv(REPO / f'build/ci-tmp/official-python-{runtime["version"]}', runtime)
    reference = output / 'official_speech_reference.json'
    kokoro = output / KOKORO_BASELINE.name
    kokoro.unlink(missing_ok=True)
    errors = output / ERROR_BASELINE.name
    errors.unlink(missing_ok=True)
    log_file = output / 'official-python.log'
    with log_file.open('w', encoding='utf-8') as log:
        result = subprocess.run([str(python.absolute()), '-B',
                                 str(PACKAGE / 'tool/generate_speech_error_reference.py'),
                                 '--output', str(errors)],
                                stdout=log, stderr=subprocess.STDOUT)
        if result.returncode == 0 and not args.errors_only:
            result = subprocess.run([str(python.absolute()), '-B',
                                     str(PACKAGE / 'tool/generate_speech_reference.py'),
                                     '--output', str(reference), '--kokoro-output', str(kokoro)],
                                    stdout=log, stderr=subprocess.STDOUT)
        # PocketTTS English, where the runner downloaded it.
        if result.returncode == 0 and not args.errors_only and POCKET_TTS_MODEL.exists():
            result = subprocess.run([str(python.absolute()), '-B',
                                     str(PACKAGE / 'tool/generate_pocket_tts_reference.py'),
                                     '--output', str(pocket_tts)],
                                    stdout=log, stderr=subprocess.STDOUT)
    print('\n'.join(log_file.read_text(encoding='utf-8', errors='replace').splitlines()[-10:]),
          flush=True)
    result.check_returncode()
    report = {'source': 'official-python-api', 'runtime': 'mediapipe==' + runtime['version'],
              'library_sha256': runtime['library_sha256'],
              'wheel_url': runtime['wheel_url'], 'wheel_sha256': runtime['wheel_sha256'],
              'os': platform.platform(), 'machine': platform.machine(),
              'error_reference_sha256': digest(errors),
              'error_baseline_sha256': digest(ERROR_BASELINE),
              'error_differences_from_macos': error_differences(
                  json.loads(ERROR_BASELINE.read_text(encoding='utf-8')),
                  json.loads(errors.read_text(encoding='utf-8')))}
    if args.errors_only:
        receipt.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(report, indent=2), flush=True)
        return
    summary = differences(json.loads(BASELINE.read_text(encoding='utf-8')),
                          json.loads(reference.read_text(encoding='utf-8')))
    pocket_tts_receipt = {}
    if pocket_tts.exists():
        # Its cases in differences()' shape, which has no transcriber.
        old, new = ({'cases': {'transcriber': {}, **json.loads(
            file.read_text(encoding='utf-8'))['cases']}} for file in (POCKET_TTS_BASELINE, pocket_tts))
        tts = new['cases']['text_to_speech']
        pocket_tts_receipt = {
            'pocket_tts_reference_sha256': digest(pocket_tts),
            'pocket_tts_baseline_sha256': digest(POCKET_TTS_BASELINE),
            'pocket_tts_checked_in_reference_differences': differences(old, new),
            # How many distinct answers Google's tasks gave each case here.
            'pocket_tts_answers': {
                name: 1 + len(case.get('alternatives', [])) for name, case in
                [*tts['utterances'].items(), ('fast', tts['fast']), ('stream', tts['stream'])]}}
    report.update({'delegate': 'CPU',
                   'reference_sha256': digest(reference), 'baseline_sha256': digest(BASELINE),
                   'checked_in_reference_differences': summary, **pocket_tts_receipt})
    # Only where the Kokoro model was downloaded: the Mac.
    if kokoro.exists():
        report.update({
            'kokoro_reference_sha256': digest(kokoro),
            'kokoro_baseline_sha256': digest(KOKORO_BASELINE),
            'checked_in_kokoro_reference_differences': kokoro_differences(
                json.loads(KOKORO_BASELINE.read_text(encoding='utf-8')),
                json.loads(kokoro.read_text(encoding='utf-8')))})
    receipt.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()

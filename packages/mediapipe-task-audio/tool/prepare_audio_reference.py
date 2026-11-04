"""Generate independent Audio Classifier references on the host running the tests.

Uses Google's checksum-pinned wheel for this host and never rewrites the
checked-in references or changes test tolerances: the clips mode reference and
the audio stream mode reference, from one run. Set
MEDIAPIPE_AUDIO_REFERENCE_DIR to the output directory to test against them.
"""
import argparse
import json
from pathlib import Path
import platform
import subprocess

from generate_audio_reference import FIXTURES, PACKAGE, host_runtime
from official_wheels import pinned_venv
from tool_helpers import digest

REPO = PACKAGE.parents[1]
BASELINE = FIXTURES / 'official_reference.json'
STREAM_BASELINE = FIXTURES / 'official_stream_reference.json'


def differences(baseline, current):
    """The largest score difference per clip, and any change in shape."""
    structural = []
    scores = {}
    if baseline['clips'].keys() != current['clips'].keys():
        structural.append('clips differ')
    for clip in baseline['clips'].keys() & current['clips'].keys():
        old, new = baseline['clips'][clip], current['clips'][clip]
        if [c['timestamp_ms'] for c in old] != [c['timestamp_ms'] for c in new]:
            structural.append(f'{clip}: chunk timestamps differ')
            continue
        error = 0.0
        for i, (left, right) in enumerate(zip(old, new)):
            names = {name for name, _ in left['top']}
            if names != {name for name, _ in right['top']}:
                structural.append(f'{clip}[{i}]: top categories differ')
                continue
            expected = dict(left['top'])
            error = max([error, *(abs(expected[name] - score) for name, score in right['top'])])
        scores[clip] = error
    return {'maximum_score_error': scores, 'structural_differences': structural}


def stream_differences(baseline, current):
    """The largest score difference per stream case, and any change in the
    results' number, timestamps, arrival or categories."""
    structural = []
    scores = {}
    if baseline['cases'].keys() != current['cases'].keys():
        structural.append('stream cases differ')
    for case in baseline['cases'].keys() & current['cases'].keys():
        old, new = baseline['cases'][case]['results'], current['cases'][case]['results']
        shape = [[r['timestamp_ms'], r['during_close']] for r in old]
        if shape != [[r['timestamp_ms'], r['during_close']] for r in new]:
            structural.append(f'{case}: result timestamps or arrival differ')
            continue
        error = 0.0
        for i, (left, right) in enumerate(zip(old, new)):
            if {name for name, _ in left['top']} != {name for name, _ in right['top']}:
                structural.append(f'{case}[{i}]: top categories differ')
                continue
            expected = dict(left['top'])
            error = max([error, *(abs(expected[name] - score) for name, score in right['top'])])
        scores[case] = error
    return {'maximum_score_error': scores, 'structural_differences': structural}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python', type=Path, help='Existing environment with the pinned wheel')
    parser.add_argument('--output-dir', type=Path, default=REPO / 'build/audio-reference')
    args = parser.parse_args()
    runtime = host_runtime()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'provenance.json'
    receipt.unlink(missing_ok=True)
    python = args.python
    if python is None:
        python = pinned_venv(REPO / f'build/ci-tmp/official-python-{runtime["version"]}', runtime)
    reference = output / 'official_reference.json'
    stream_reference = output / 'official_stream_reference.json'
    log_file = output / 'official-python.log'
    with log_file.open('w', encoding='utf-8') as log:
        result = subprocess.run([str(python.absolute()), '-B',
                                 str(PACKAGE / 'tool/generate_audio_reference.py'),
                                 '--output', str(reference),
                                 '--stream-output', str(stream_reference)],
                                stdout=log, stderr=subprocess.STDOUT)
    print('\n'.join(log_file.read_text(encoding='utf-8', errors='replace').splitlines()[-10:]),
          flush=True)
    result.check_returncode()
    summary = differences(json.loads(BASELINE.read_text(encoding='utf-8')),
                          json.loads(reference.read_text(encoding='utf-8')))
    stream_summary = stream_differences(
        json.loads(STREAM_BASELINE.read_text(encoding='utf-8')),
        json.loads(stream_reference.read_text(encoding='utf-8')))
    report = {'source': 'official-python-api', 'runtime': 'mediapipe==' + runtime['version'],
              'delegate': 'CPU', 'library_sha256': runtime['library_sha256'],
              'wheel_url': runtime['wheel_url'], 'wheel_sha256': runtime['wheel_sha256'],
              'os': platform.platform(), 'machine': platform.machine(),
              'reference_sha256': digest(reference), 'baseline_sha256': digest(BASELINE),
              'stream_reference_sha256': digest(stream_reference),
              'stream_baseline_sha256': digest(STREAM_BASELINE),
              'checked_in_reference_differences': summary,
              'checked_in_stream_reference_differences': stream_summary}
    receipt.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()

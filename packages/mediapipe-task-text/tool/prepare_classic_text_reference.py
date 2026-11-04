"""Generate independent CPU text references on the host running the Dart tests.

Uses Google's checksum-pinned wheel; never rewrites the checked-in references or
changes test tolerances. Python is used only to prepare the test oracle, outside
the fresh consumer build where native build tools and Python remain blocked.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import subprocess

from generate_classic_text_reference import PACKAGE
from official_wheels import host_runtime, pinned_venv
from tool_helpers import digest

REPO = PACKAGE.parents[1]
BASELINE = PACKAGE / 'test/fixtures/classic_text/official_reference.json'


def reference_file():
    """Select a verified host oracle, or the reviewed physical-Mac baseline."""
    directory = os.environ.get('MEDIAPIPE_CLASSIC_TEXT_REFERENCE_DIR')
    if directory is None:
        return BASELINE
    root = Path(directory)
    reference = root / 'official_reference.json'
    receipt = json.loads((root / 'provenance.json').read_text(encoding='utf-8'))
    current = json.loads(reference.read_text(encoding='utf-8'))
    baseline = json.loads(BASELINE.read_text(encoding='utf-8'))
    runtime = host_runtime()
    if (receipt.get('source') != 'official-python-api'
            or receipt.get('runtime') != 'mediapipe==' + runtime['version']
            or receipt.get('delegate') != 'CPU'
            or receipt.get('library_sha256') != runtime['library_sha256']
            or receipt.get('wheel_sha256') != runtime['wheel_sha256']
            or receipt.get('reference_sha256') != digest(reference)
            or receipt.get('baseline_sha256') != digest(BASELINE)
            or current.get('runtime') != receipt['runtime']
            or current.get('library_sha256') != receipt['library_sha256']
            or any(current.get(key) != baseline[key]
                   for key in ('delegate', 'models', 'abi'))):
        raise RuntimeError('Invalid same-host official classic text reference')
    return reference


def differences(baseline, current):
    groups = {}
    structural = []

    def visit(old, new, path, group):
        if type(old) is not type(new):
            structural.append(path + ': type differs')
        elif isinstance(old, dict):
            if old.keys() != new.keys():
                structural.append(path + ': keys differ')
            for key in old.keys() & new.keys():
                visit(old[key], new[key], path + '.' + key, old.get('task', group))
        elif isinstance(old, list):
            if len(old) != len(new):
                structural.append(path + ': length differs')
            for i, (left, right) in enumerate(zip(old, new)):
                visit(left, right, f'{path}[{i}]', group)
        elif isinstance(old, (int, float)) and not isinstance(old, bool):
            error = abs(old - new)
            item = groups.setdefault(group, {'maximum_absolute_error': 0.0, 'path': None})
            if error > item['maximum_absolute_error']:
                item.update(maximum_absolute_error=error, path=path,
                            checked_in=old, same_host=new)
        elif old != new:
            structural.append(path + ': value differs')

    for section in ('cases', 'similarities', 'creation_errors', 'lifecycle_sequences'):
        visit(baseline[section], current[section], section, section)
    return {'numeric_groups': groups, 'structural_differences': structural}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python', type=Path, help="Existing environment holding this host's official wheel")
    parser.add_argument('--python-package-root', type=Path, help='Extracted official wheel')
    parser.add_argument('--output-dir', type=Path, default=REPO / 'build/classic-text-reference')
    args = parser.parse_args()
    runtime = host_runtime()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'provenance.json'
    receipt.unlink(missing_ok=True)
    python = args.python
    if python is None:
        python = pinned_venv(
            REPO / f'build/ci-tmp/classic-text-reference-env-{runtime["version"]}', runtime)
    reference = output / 'official_reference.json'
    command = [str(python.absolute()), '-B', str(PACKAGE / 'tool/generate_classic_text_reference.py'),
               '--output', str(reference)]
    if args.python_package_root:
        command.extend(['--python-package-root', str(args.python_package_root.resolve())])
    log_file = output / 'official-python.log'
    with log_file.open('w', encoding='utf-8') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    print('\n'.join(log_file.read_text(encoding='utf-8', errors='replace').splitlines()[-15:]), flush=True)
    result.check_returncode()
    summary = differences(json.loads(BASELINE.read_text(encoding='utf-8')), json.loads(reference.read_text(encoding='utf-8')))
    if summary['structural_differences']:
        raise RuntimeError(f'Official reference structure changed: {summary}')
    report = {'source': 'official-python-api', 'runtime': 'mediapipe==' + runtime['version'],
              'delegate': 'CPU', 'library_sha256': runtime['library_sha256'],
              'wheel_url': runtime['wheel_url'], 'wheel_sha256': runtime['wheel_sha256'],
              'os': platform.platform(), 'machine': platform.machine(),
              'reference_sha256': digest(reference), 'baseline_sha256': digest(BASELINE),
              'checked_in_reference_differences': summary}
    receipt.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()

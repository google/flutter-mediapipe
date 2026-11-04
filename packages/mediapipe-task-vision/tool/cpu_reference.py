"""Generate official CPU references on the host that runs the Dart tests.

The checked-in goldens come from one physical macOS arm64 machine. The official
wheel's own results drift between hosts, so every job that compares a native
runtime against them regenerates the reference with the checksum-pinned wheel
for its own host and records how far the checked-in goldens sit from it. Nothing
here changes goldens, models, graphs or test tolerances.
"""
import argparse
import json
from pathlib import Path
import platform
import sys

from prepare_gpu_reference import difference
from test_desktop import PACKAGE, REPO

sys.path.insert(0, str(REPO / 'packages/mediapipe-core/tool'))
from official_wheels import pinned_venv, reference_wheel  # noqa: E402
from tool_helpers import digest, run  # noqa: E402

FACE_TASKS = [('face_detector', 'face_detection'),
              ('face_landmarker', 'face_landmarker')]
FACE_FILES = ['face_detection/official_reference.json',
              'face_detection/official_video_reference.json',
              'face_landmarker/official_reference.json']

def host_target():
    """The pinned wheel target matching this host, or None when unsupported."""
    system = platform.system()
    machine = platform.machine().lower()
    if system == 'Darwin' and machine == 'arm64':
        return 'macos/arm64'
    if machine in ('amd64', 'x86_64'):
        return {'Linux': 'linux/x64', 'Windows': 'windows/x64'}.get(system)
    return None


def wheel_pin(target):
    """Returns the pinned wheel URL, wheel and native library digests, and version."""
    wheel = reference_wheel(target)
    return (wheel['wheel_url'], wheel['wheel_sha256'], wheel['library_sha256'],
            wheel['version'])


def install(root, target):
    """Creates an isolated environment holding only the pinned official wheel."""
    root.mkdir(parents=True, exist_ok=True)
    return pinned_venv(root / 'python', reference_wheel(target), log=root / 'pip.log')


def generate(root, output, target, tasks=FACE_TASKS, files=FACE_FILES,
             python=None, env=None):
    """Writes references and a provenance receipt for `target` into `output`."""
    wheel_url, wheel_sha, library_sha, version = wheel_pin(target)
    root.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    if python is None:
        python = install(root, target)
    for task, folder in tasks:
        run([python, '-u', '-X', 'faulthandler', '-B',
             PACKAGE / f'tool/generate_{task}_reference.py',
             '--output-dir', output / folder], REPO,
            root / f'{task}-reference.log', env=env)
    comparisons = {}
    for name in files:
        reference = json.loads((output / name).read_text())
        if reference['library_sha256'] != library_sha:
            raise RuntimeError('Independent reference used a different native library')
        comparisons[name] = difference(
            json.loads((PACKAGE / 'test/fixtures' / name).read_text()), reference)
    provenance = {
        'runtime': 'mediapipe==' + version, 'source': 'official-python-api',
        'delegate': 'CPU', 'target': target,
        'library_sha256': library_sha, 'wheel_sha256': wheel_sha,
        'files': {name: digest(output / name) for name in files},
        'checked_in_reference_differences': comparisons,
    }
    (output / 'provenance.json').write_text(json.dumps(provenance, indent=2))
    return {'python': python, 'wheel_url': wheel_url, 'wheel_sha256': wheel_sha,
            'library_sha256': library_sha, 'comparisons': comparisons,
            'provenance': provenance}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--target', help='Defaults to this host')
    args = parser.parse_args()
    target = args.target or host_target()
    if target is None:
        raise SystemExit('No official CPU wheel is pinned for this host.')
    output = args.output_dir.resolve()
    result = generate(output, output, target)
    print(json.dumps(result['comparisons'], indent=2), flush=True)
    print(f'Verified official {target} CPU references: {output}', flush=True)


if __name__ == '__main__':
    main()

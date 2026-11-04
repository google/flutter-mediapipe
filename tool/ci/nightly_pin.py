"""Pins a Google nightly for .github/workflows/nightly-compare.yaml.

Runs `packages/mediapipe-core/tool/pin_nightly.py --generation`, which hashes
Google's archive once and pins its generation, then moves the browser
runtimes to the npm prerelease of the same night (`1.2.0-rc.<YYYYMMDD>`) when
npm has it for every family. The changed files go to `<out>/files/` for the
comparison jobs to copy over their checkout (.github/actions/nightly-pin),
next to the change as a patch, pin_nightly's report and its log:

    python3 -B tool/ci/nightly_pin.py --nightly newest --out build/nightly-pin

With GITHUB_OUTPUT set it writes the step outputs: nightly, generation,
previous, scope, patched (true when the patch exists), api_changed, web (true
when the browser runtimes moved too) and web_note. It fails only when
pin_nightly stopped for another reason than a C API change (no complete
build, or a new MediaPipe version, which is moved by hand).

The browser pins are each family's `assets/runtime.json` (version, the
tarball's npm integrity, every loaded file's SHA-384) and the version core's
`tasksRuntimeVersionOn` reports, which a test of the text package names.
"""
import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import urllib.error
import urllib.request

REPO = Path(__file__).resolve().parents[2]
PIN_NIGHTLY = REPO / 'packages/mediapipe-core/tool/pin_nightly.py'
REGISTRY = 'https://registry.npmjs.org/'
# Files that name the browser runtime's version besides runtime.json.
WEB_VERSION_NAMED = [
    'packages/mediapipe-core/lib/src/capabilities/task_capabilities.dart',
    'packages/mediapipe-task-text/test/capabilities_test.dart',
]
# The weekly cron line; any other schedule is the daily set.
FULL_SCHEDULE = '0 14 * * 0'


def scope_of(event, schedule, full):
    """'full' or 'daily' for this run's trigger: the weekly schedule, or a
    dispatch (or pull request) that asks for the full matrix, runs it all."""
    if event == 'schedule':
        return 'full' if schedule == FULL_SCHEDULE else 'daily'
    return 'full' if full == 'true' else 'daily'


def runtime_pins():
    """`{path: pin}` for every family's assets/runtime.json."""
    return {path: json.loads(path.read_text(encoding='utf-8'))
            for path in sorted(REPO.glob('packages/mediapipe-task-*/assets/runtime.json'))}


def web_version(current, stamp):
    """The npm prerelease of night `stamp`, in the form the pins use now."""
    prefix, separator, _ = current.rpartition('-rc.')
    if not separator:
        raise SystemExit(f'The browser runtime {current} is not an npm nightly (-rc.).')
    return f'{prefix}-rc.{stamp}'


def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url), timeout=120) as response:
        return response.read()


def registry_entry(package, version):
    """npm's metadata for `package@version`, or None when it is not published."""
    try:
        return json.loads(fetch(f'{REGISTRY}{package}/{version}'))
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise


def file_pins(pin, tarball):
    """`(integrity, {file: sha384})` as runtime.json pins them, checked against
    npm's integrity for the tarball."""
    integrity = base64.b64encode(hashlib.sha512(tarball).digest()).decode()
    sha384 = {}
    with tarfile.open(fileobj=io.BytesIO(tarball), mode='r:gz') as archive:
        for name in pin['files']:
            member = archive.extractfile(f'package/{name}')
            if member is None:
                raise SystemExit(f"{pin['package']}: the tarball has no {name}")
            sha384[name] = base64.b64encode(hashlib.sha384(member.read()).digest()).decode()
    return integrity, sha384


def pin_web(stamp):
    """Moves every browser runtime to night `stamp`; returns a note, and
    whether it did."""
    pins = runtime_pins()
    old = {pin['version'] for pin in pins.values()}
    if len(old) != 1:
        raise SystemExit(f'The families pin different browser runtimes: {sorted(old)}')
    old = old.pop()
    version = web_version(old, stamp)
    entries = {path: registry_entry(pin['package'], version) for path, pin in pins.items()}
    missing = [pins[path]['package'] for path, entry in entries.items() if entry is None]
    if missing:
        return f"npm has no {version} of {', '.join(missing)} yet", False
    for path, pin in pins.items():
        dist = entries[path]['dist']
        tarball = fetch(dist['tarball'])
        integrity, sha384 = file_pins(pin, tarball)
        if dist.get('integrity') != f'sha512-{integrity}':
            raise SystemExit(f"{pin['package']}@{version}: the tarball does not match "
                             "npm's integrity")
        pin.update(version=version, integrity=integrity, sha384=sha384)
        path.write_text(json.dumps(pin, indent=2) + '\n', encoding='utf-8')
    for relative in WEB_VERSION_NAMED:
        path = REPO / relative
        text = path.read_text(encoding='utf-8')
        if f"'{old}'" not in text:
            raise SystemExit(f"{relative} does not name '{old}'")
        path.write_text(text.replace(f"'{old}'", f"'{version}'"), encoding='utf-8')
    return f'browser runtimes moved from {old} to {version}', True


def outputs(values):
    lines = ''.join(f'{key}={value}\n' for key, value in values.items())
    print(lines, end='')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
            output.write(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--nightly', default='newest', help='YYYYMMDD or newest')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--event', default='workflow_dispatch')
    parser.add_argument('--schedule', default='')
    parser.add_argument('--full', default='false')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    report_path, log_path = args.out / 'report.json', args.out / 'pin.log'
    with open(log_path, 'w', encoding='utf-8') as log:
        status = subprocess.run(
            [sys.executable, '-B', str(PIN_NIGHTLY), '--nightly', args.nightly,
             '--generation', '--report', str(report_path)],
            cwd=REPO, stdout=log, stderr=subprocess.STDOUT).returncode
    print(log_path.read_text(encoding='utf-8'), end='', flush=True)
    if not report_path.exists():
        raise SystemExit(f'pin_nightly.py exited {status} before choosing a build.')
    report = json.loads(report_path.read_text(encoding='utf-8'))
    api_changed = bool(report['api_changes'])
    if status != 0 and not api_changed:
        raise SystemExit(f'pin_nightly.py exited {status}.')
    patched = status == 0 and report['written']
    web, web_note = False, 'not pinned: the native pin did not apply'
    if patched:
        web_note, web = pin_web(report['nightly'])
        patch = subprocess.run(['git', 'diff', '--binary'], cwd=REPO, check=True,
                               capture_output=True).stdout
        (args.out / 'nightly.patch').write_bytes(patch)
        # The changed files themselves, which the jobs copy over their
        # checkout: a patch does not apply to a Windows checkout's CRLF files.
        changed = subprocess.run(['git', 'diff', '--name-only'], cwd=REPO, check=True,
                                 capture_output=True, text=True).stdout.split()
        for relative in changed:
            target = args.out / 'files' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((REPO / relative).read_bytes())
        subprocess.run(['git', 'diff', '--stat'], cwd=REPO, check=True)
    report['web'] = {'pinned': web, 'note': web_note}
    report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    outputs({'nightly': report['nightly'], 'generation': report['generation'],
             'previous': report['previous'],
             'scope': scope_of(args.event, args.schedule, args.full),
             'patched': str(patched).lower(), 'api_changed': str(api_changed).lower(),
             'web': str(web).lower(), 'web_note': web_note})


if __name__ == '__main__':
    main()

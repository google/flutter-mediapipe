"""Pins a Google nightly for .github/workflows/nightly-compare.yaml.

Runs `packages/mediapipe-core/tool/pin_nightly.py --generation`, which hashes
Google's archive once and pins its generation, then moves the browser
runtimes to the npm prerelease of the same night (`1.2.2-rc.<YYYYMMDD>`) when
npm has it for every family. The changed files go to `<out>/files/` for the
comparison jobs to copy over their checkout (.github/actions/nightly-pin),
next to the change as a patch, pin_nightly's report and its log:

    python3 -B tool/ci/nightly_pin.py --nightly newest --out build/nightly-pin

With GITHUB_OUTPUT set it writes the step outputs: nightly, generation,
previous, scope, patched (true when the patch exists), api_changed, held (true
when the newest build names a new MediaPipe version), network_failed (true when
the network kept pin_nightly from choosing a build or reading its archive, which
only warns, and the only output that is set then), web (true when the browser
runtimes moved too)
and web_note. It fails when pin_nightly stopped for another reason than the
network, a C API change or that new version, which is moved by hand, and when
that version has stopped the comparison for over FAIL_AFTER_DAYS. npm failing,
after retries, leaves the browser runtimes as they are and says so in
web_note: the native comparison runs without them.

The browser pins are each family's `assets/runtime.json` (version, the
tarball's npm integrity, every loaded file's SHA-384) and the version core's
`tasksRuntimeVersionOn` reports, which a test of the text package names.
"""
import argparse
import base64
import datetime
import hashlib
import http.client
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import time
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
# How long a new MediaPipe version may stop the comparison before a run warns,
# and before it fails, counted from Google's first build of it.
WARN_AFTER_DAYS = 14
FAIL_AFTER_DAYS = 90
# Seconds between attempts at an npm request that failed in a way that may pass.
RETRY_DELAYS = (5, 20)


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
    """The npm prerelease of night `stamp`, for a pin on a release of that
    version or on another of its prereleases."""
    return f"{current.partition('-rc.')[0]}-rc.{stamp}"


def passing(error):
    """Whether a failed request may succeed when tried again: no answer, a
    dropped connection, or a server error."""
    if isinstance(error, urllib.error.HTTPError):
        return error.code == 429 or error.code >= 500
    return True


def fetch(url):
    for delay in (*RETRY_DELAYS, None):
        try:
            with urllib.request.urlopen(urllib.request.Request(url), timeout=120) as response:
                return response.read()
        except (OSError, http.client.HTTPException) as error:
            if delay is None or not passing(error):
                raise
            print(f'{url}: {error}; trying again in {delay} s', file=sys.stderr, flush=True)
            time.sleep(delay)


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
    whether it did. Nothing is written until every tarball is in and checked,
    so a failure leaves all of them as they were."""
    pins = runtime_pins()
    old = {pin['version'] for pin in pins.values()}
    if len(old) != 1:
        raise SystemExit(f'The families pin different browser runtimes: {sorted(old)}')
    old = old.pop()
    version = web_version(old, stamp)
    named = {relative: (REPO / relative).read_text(encoding='utf-8')
             for relative in WEB_VERSION_NAMED}
    for relative, text in named.items():
        if f"_webRuntimeVersion = '{old}'" not in text:
            raise SystemExit(f"{relative} does not name '{old}'")
    try:
        entries = {path: registry_entry(pin['package'], version) for path, pin in pins.items()}
        missing = [pins[path]['package'] for path, entry in entries.items() if entry is None]
        if missing:
            return f"npm has no {version} of {', '.join(missing)} yet", False
        tarballs = {path: fetch(entries[path]['dist']['tarball']) for path in pins}
    except (OSError, http.client.HTTPException) as error:
        return f'not pinned: npm failed for {version} ({error})', False
    for path, pin in pins.items():
        integrity, sha384 = file_pins(pin, tarballs[path])
        if entries[path]['dist'].get('integrity') != f'sha512-{integrity}':
            return (f"not pinned: the tarball of {pin['package']}@{version} does not "
                    "match npm's integrity"), False
        pin.update(version=version, integrity=integrity, sha384=sha384)
    for path, pin in pins.items():
        path.write_text(json.dumps(pin, indent=2) + '\n', encoding='utf-8')
    for relative, text in named.items():
        (REPO / relative).write_text(text.replace(f"_webRuntimeVersion = '{old}'",
                                                  f"_webRuntimeVersion = '{version}'"),
                                     encoding='utf-8')
    return f'browser runtimes moved from {old} to {version}', True


def today():
    return datetime.datetime.now(datetime.timezone.utc).date()


def add_to_summary(note):
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as step:
            step.write(note + '\n')


def network_failed(failure, step=None):
    """Reports a run the network kept from choosing a build, or from reading
    the chosen build's archive (`step`, as pin_nightly names it): a warning on
    every event, since nothing was compared and the next run tries again."""
    step = step or "choosing Google's build"
    note = (f'The comparison did not run: the network failed while {step} '
            f'({failure}). The next run tries again.')
    add_to_summary(note)
    print(f'::warning::{note}', flush=True)


def hold(stop, event):
    """Reports a comparison that a new MediaPipe version has stopped: a log line,
    a warning past WARN_AFTER_DAYS, a failure past FAIL_AFTER_DAYS. A pull request
    only warns, since it did not cause this. When the network kept pin_nightly
    from counting the days it warns and passes; the next run counts again."""
    note = (f"The comparison is stopped: Google's nightlies name MediaPipe {stop['version']} "
            f"and the pin is on {stop['pinned']}. Move the version by hand (pin_nightly.py) "
            'to compare again.')
    level = 'warning'
    if stop['since'] is None:
        note += ' The days behind could not be counted on this run.'
    else:
        since = datetime.datetime.strptime(stop['since'], '%Y%m%d').date()
        days = (today() - since).days
        red = since + datetime.timedelta(days=FAIL_AFTER_DAYS + 1)
        note += (f" {days} days behind, since {stop['since']}. Scheduled runs fail from "
                 f'{red.isoformat()}.')
        if days > FAIL_AFTER_DAYS and event != 'pull_request':
            level = 'error'
            note = f'Nightly comparison stopped for over {FAIL_AFTER_DAYS} days. {note}'
        elif days <= WARN_AFTER_DAYS:
            level = None
    add_to_summary(note)
    print(f'::{level}::{note}' if level else note, flush=True)
    if level == 'error':
        raise SystemExit(note)


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
        raise SystemExit(f'pin_nightly.py exited {status} and wrote no report.')
    report = json.loads(report_path.read_text(encoding='utf-8'))
    if report.get('network_failure'):
        network_failed(report['network_failure'], report.get('network_failed_while'))
        outputs({'network_failed': 'true'})
        return
    api_changed = bool(report['api_changes'])
    # Only the newest build: a night asked for by name was asked for to be pinned.
    stop = report.get('version_stop') if args.nightly == 'newest' else None
    if stop:
        hold(stop, args.event)
    elif status != 0 and not api_changed:
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
             'held': str(bool(stop)).lower(), 'network_failed': 'false',
             'web': str(web).lower(), 'web_note': web_note})


if __name__ == '__main__':
    main()

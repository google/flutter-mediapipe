"""Google's browser runtimes for CI's browser tests, from more than one source.

Writes every family's pinned runtime (`packages/mediapipe-task-*/assets/
runtime.json`) to `<out>/<package>@<version>/<file>`, the layout `dart run
mediapipe_core:web_runtime` writes and gallery/tool/web_server.py serves at
/runtime/, so no browser test has to reach a CDN while it runs:

    python3 -B tool/ci/web_runtime.py gallery/build/web-runtime

A file already there with its pinned SHA-384 is kept, so a copy restored from
the cache (.github/actions/web-runtime) costs no request. The rest come from
npm's tarball, which must match the pin's SHA-512 integrity, and failing that
file by file from jsDelivr and then unpkg, both of which serve the same npm
package. Every file must match its pinned SHA-384, whichever source sent it.
Each request is tried as packages/mediapipe-core/lib/src/verified_download.dart
tries one: up to three times on no answer, a timeout or HTTP 408, 429 or 5xx,
with a random wait up to min(30 s, 1 s x 2^attempt) or the server's
Retry-After up to 30 s. A family no source could give fails the step, naming
every source tried and how each failed.

The browsers' own requests to jsDelivr are what failed in CI: on 2026-10-15
(ASSET_HOSTING.md) and again on 2026-11-16 (PR #95, run 43518618) jsDelivr
answered cache misses with 502 or 503 and no Access-Control-Allow-Origin
header, so a worker saw only "Failed to fetch". The page cannot retry what it
cannot read; this step can.

With --check it instead reads every pinned file from jsDelivr and unpkg, as a
browser would load it, and fails unless each one matches its SHA-384 and
allows any origin; .github/workflows/web-runtime-hosts.yaml runs it daily.
"""
import argparse
import base64
import hashlib
import http.client
import io
import json
from pathlib import Path
import random
import re
import shutil
import sys
import tarfile
import time
import urllib.error
import urllib.request

REPO = Path(__file__).resolve().parents[2]
ATTEMPTS = 3
TIMEOUT = 60
# The CDNs that serve an npm package's files by name, as MediaPipeWebRuntime's
# baseUrl takes them: `<root><package>@<version>/<file>`.
CDNS = {
    'jsDelivr': 'https://cdn.jsdelivr.net/npm/',
    'unpkg': 'https://unpkg.com/',
}
REGISTRY = 'https://registry.npmjs.org/'
# Leaves the waits out of the offline tests.
sleep = time.sleep


def runtime_pins():
    """Every family's pin, checked so its names cannot leave the output folder."""
    pins = []
    for path in sorted(REPO.glob('packages/mediapipe-task-*/assets/runtime.json')):
        pin = json.loads(path.read_text(encoding='utf-8'))
        package, version = pin['package'], pin['version']
        if not re.fullmatch(r'@mediapipe/tasks-[a-z]+', package) or not re.fullmatch(r'[0-9A-Za-z.+-]+', version) \
                or '..' in version:
            raise SystemExit(f'{path}: an unexpected package or version: {package}@{version}')
        for name in pin['files']:
            if name.startswith('/') or '..' in name.split('/') or name not in pin['sha384']:
                raise SystemExit(f'{path}: an unexpected file: {name}')
        pins.append(pin)
    if not pins:
        raise SystemExit('No packages/mediapipe-task-*/assets/runtime.json')
    return pins


def sha384(data):
    return base64.b64encode(hashlib.sha384(data).digest()).decode()


def retrying(error):
    """Whether a failed request may succeed when tried again: no answer, a
    dropped connection, a timeout, or HTTP 408, 429 or a server error."""
    if isinstance(error, urllib.error.HTTPError):
        return error.code in (408, 429) or error.code >= 500
    return True


def wait_before(attempt, error):
    after = getattr(error, 'headers', None) and error.headers.get('Retry-After')
    if after and after.isdigit():
        return min(int(after), 30)
    return random.uniform(0, min(30, 2 ** attempt))


def fetch(url, headers=False):
    """The body at `url` (and its headers when asked), after up to ATTEMPTS tries."""
    for attempt in range(1, ATTEMPTS + 1):
        try:
            request = urllib.request.Request(url, headers={'User-Agent': 'flutter-mediapipe-ci'})
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                body = response.read()
                return (body, response.headers) if headers else body
        except (OSError, http.client.HTTPException) as error:
            if attempt == ATTEMPTS or not retrying(error):
                raise RuntimeError(f'{error}, after {attempt} attempt{"s" if attempt > 1 else ""}') from error
            delay = wait_before(attempt, error)
            print(f'{url}: {error}; trying again in {delay:.1f} s', file=sys.stderr, flush=True)
            sleep(delay)


def from_registry(pin):
    """`{file: bytes}` from npm's tarball, which must match the pin's integrity."""
    package, version = pin['package'], pin['version']
    tarball = fetch(f'{REGISTRY}{package}/-/{package.split("/")[1]}-{version}.tgz')
    integrity = base64.b64encode(hashlib.sha512(tarball).digest()).decode()
    if integrity != pin['integrity']:
        raise RuntimeError(f'the tarball is sha512-{integrity}, not the pinned sha512-{pin["integrity"]}')
    files = {}
    with tarfile.open(fileobj=io.BytesIO(tarball), mode='r:gz') as archive:
        for name in pin['files']:
            member = archive.extractfile(f'package/{name}')
            if member is None:
                raise RuntimeError(f'the tarball has no {name}')
            files[name] = member.read()
    return files


def from_cdn(root):
    """A source that reads each file from a CDN serving npm packages."""
    def source(pin):
        return {name: fetch(f'{root}{pin["package"]}@{pin["version"]}/{name}') for name in pin['files']}
    return source


SOURCES = [('npm registry', from_registry)] + [(name, from_cdn(root)) for name, root in CDNS.items()]


def host(pin, out):
    """Writes `pin`'s files under `out`, keeping those already there with their
    SHA-384; returns how many were fetched. Raises naming every source tried."""
    directory = out / f'{pin["package"]}@{pin["version"]}'
    missing = [name for name in pin['files']
               if not (directory / name).is_file() or sha384((directory / name).read_bytes()) != pin['sha384'][name]]
    if not missing:
        return 0
    failures = []
    for name, source in SOURCES:
        try:
            files = source(pin)
            wrong = [f for f in pin['files'] if sha384(files[f]) != pin['sha384'][f]]
            if wrong:
                raise RuntimeError('SHA-384 mismatch for ' + ', '.join(wrong))
        except Exception as error:  # noqa: BLE001: every source's failure is reported
            failures.append(f'{name}: {error}')
            print(f'{pin["package"]}@{pin["version"]} from {name} failed: {error}', file=sys.stderr, flush=True)
            continue
        # Written beside the copy and moved over it whole, so a failure never
        # leaves a half-written family behind.
        staging = directory.with_name(directory.name + '.partial')
        shutil.rmtree(staging, ignore_errors=True)
        for file, data in files.items():
            (staging / file).parent.mkdir(parents=True, exist_ok=True)
            (staging / file).write_bytes(data)
        shutil.rmtree(directory, ignore_errors=True)
        directory.parent.mkdir(parents=True, exist_ok=True)
        staging.rename(directory)
        print(f'{pin["package"]}@{pin["version"]}: {len(missing)} of {len(pin["files"])} files from {name}', flush=True)
        return len(missing)
    raise RuntimeError(f'{pin["package"]}@{pin["version"]}: no source gave the pinned files. ' + '; '.join(failures))


def check():
    """Problems with the CDNs as browsers load the pinned files from them."""
    problems = []
    for pin in runtime_pins():
        for cdn, root in CDNS.items():
            for name in pin['files']:
                url = f'{root}{pin["package"]}@{pin["version"]}/{name}'
                try:
                    body, headers = fetch(url, headers=True)
                except RuntimeError as error:
                    problems.append(f'{url}: {error}')
                    continue
                if sha384(body) != pin['sha384'][name]:
                    problems.append(f'{url}: sha384-{sha384(body)}, not the pinned sha384-{pin["sha384"][name]}')
                elif headers.get('Access-Control-Allow-Origin') != '*':
                    problems.append(f'{url}: Access-Control-Allow-Origin is '
                                    f'{headers.get("Access-Control-Allow-Origin")!r}, not *')
                else:
                    print(f'{cdn}: {pin["package"]}@{pin["version"]}/{name} matches its pin', flush=True)
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('out', nargs='?', type=Path, help='where to write the runtimes')
    parser.add_argument('--check', action='store_true', help="check the CDNs' copies instead")
    args = parser.parse_args()
    if args.check:
        problems = check()
        for problem in problems:
            print(f'::error title=A CDN no longer serves a pinned runtime file::{problem}', flush=True)
        return 1 if problems else 0
    if args.out is None:
        parser.error('the output folder is required without --check')
    out = args.out if args.out.is_absolute() else Path.cwd() / args.out
    failed = False
    for pin in runtime_pins():
        try:
            host(pin, out)
        except RuntimeError as error:
            print(f'::error title=Google\'s browser runtime could not be copied::{error}', flush=True)
            failed = True
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())

"""Validates and publishes the repository's packages to pub.dev.

Every package shares one version (`tool/check_repository.py`), and the task
families depend on `mediapipe_core` by that version. A release therefore:

1. Checks that every package's `pubspec.yaml` and `CHANGELOG.md` name the same
   version, and that a real publish runs on tag `refs/tags/v<version>` (the
   `v{{version}}` tag pattern pub.dev's automated publishing verifies).
2. Copies every package outside the repository as `publish_check.py` does and
   runs `flutter pub publish --dry-run` on each selected package, refusing to
   proceed unless every package validates with zero warnings.
3. With `--dry-run`, stops there.
4. Otherwise registers `PUB_TOKEN` with `dart pub token add https://pub.dev
   --env-var PUB_TOKEN`, mints a fresh GitHub Actions OIDC token for audience
   `https://pub.dev` before each upload, publishes `mediapipe_core` first,
   waits for pub.dev to list the new `mediapipe_core` version, and then
   publishes the five task family packages in order. Any package whose target
   version is already on pub.dev is skipped so a retried run finishes cleanly.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

REPO = Path(__file__).resolve().parents[2]
CORE_TOOL = REPO / 'packages/mediapipe-core/tool'
sys.path.insert(0, str(CORE_TOOL))
from families import CORE, PACKAGES, package_folders, package_name  # noqa: E402
from publish_check import flutter_dry_run, prepare  # noqa: E402

PUB_HOST = 'https://pub.dev'
CLEAN_DRY_RUN = re.compile(r'Package has 0 warnings(\.| and)')


def executable_path(name):
    binary = f'{name}.bat' if platform.system() == 'Windows' else name
    return shutil.which(binary) or binary


def flutter_publish():
    """The non-interactive publish command, run only after `flutter_dry_run`
    confirmed zero warnings on the same staged directory."""
    return [executable_path('flutter'), 'pub', 'publish', '--force']


def dart_token_add():
    return [executable_path('dart'), 'pub', 'token', 'add', PUB_HOST,
            '--env-var', 'PUB_TOKEN']


def resolve_packages(raw_names):
    """Resolves package folder names or pubspec names to `package_folders()`
    order, keeping `mediapipe-core` first whenever it is selected."""
    all_folders = package_folders()
    by_name = {package_name(folder): folder for folder in all_folders}
    tokens = []
    for item in raw_names:
        for part in re.split(r'[,\s]+', item.strip()):
            if part and part != 'all':
                tokens.append(part)
    if not tokens:
        return all_folders
    selected = set()
    for token in tokens:
        if token in all_folders:
            selected.add(token)
        elif token in by_name:
            selected.add(by_name[token])
        else:
            known = ', '.join(f'{folder} ({package_name(folder)})' for folder in all_folders)
            raise SystemExit(f'Unknown package {token!r}. Known packages: {known}')
    return [folder for folder in all_folders if folder in selected]


def verify_versions_and_tag(ref, dry_run):
    """Checks that every package's pubspec and CHANGELOG agree on the release
    version, and that `ref` matches `refs/tags/v<version>` when publishing."""
    versions = {}
    for folder in package_folders():
        pubspec = (PACKAGES / folder / 'pubspec.yaml').read_text(encoding='utf-8')
        match = re.search(r'^version:\s*(\S+)$', pubspec, re.M)
        if not match:
            raise SystemExit(f'packages/{folder}/pubspec.yaml has no version field.')
        version = match.group(1)
        versions[folder] = version
        changelog = (PACKAGES / folder / 'CHANGELOG.md').read_text(encoding='utf-8')
        if not re.search(rf'^## {re.escape(version)}\b', changelog, re.M):
            raise SystemExit(
                f'packages/{folder}/CHANGELOG.md has no "## {version}" section.')
    unique = sorted(set(versions.values()))
    if len(unique) != 1:
        raise SystemExit(f'Package versions do not agree: {versions}')
    version = unique[0]
    expected_ref = f'refs/tags/v{version}'
    if ref and ref.startswith('refs/tags/') and ref != expected_ref:
        raise SystemExit(
            f'Tag ref {ref!r} does not match pubspec version {version} '
            f'(expected {expected_ref!r}).')
    if not dry_run and ref != expected_ref:
        raise SystemExit(
            f'Refusing to publish version {version} from ref {ref!r}: '
            f'publishing requires tag ref {expected_ref!r}.')
    return version


def validate_staged(root, selected):
    """Runs `flutter pub publish --dry-run` on each selected package in `root`
    and fails unless every package reports 0 warnings."""
    for folder in selected:
        result = subprocess.run(flutter_dry_run(), cwd=root / folder,
                                capture_output=True, encoding='utf-8',
                                errors='replace')
        output = result.stdout + result.stderr
        size = re.search(r'Total compressed archive size: (.+)\.', output)
        clean = result.returncode == 0 and CLEAN_DRY_RUN.search(output) is not None
        print(f'{folder} ({package_name(folder)}): '
              f'{"dry-run ok" if clean else "DRY-RUN FAILED"}, '
              f'archive {size.group(1) if size else "unknown"}', flush=True)
        if not clean:
            report = output[output.find('Validating package'):]
            print(report or output, flush=True)
            raise SystemExit(f'{folder}: dry-run validation failed.')


def is_version_published(pkg_name, version, pub_host=PUB_HOST):
    """True when `pub.dev` already lists `version` of `pkg_name`."""
    url = f'{pub_host}/api/packages/{pkg_name}'
    request = urllib.request.Request(
        url, headers={'Accept': 'application/vnd.pub.v2+json'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise
    published = {entry.get('version') for entry in payload.get('versions', [])}
    return version in published


def wait_for_version(pkg_name, version, timeout_seconds=180, poll_seconds=5,
                     pub_host=PUB_HOST):
    """Polls pub.dev until `pkg_name` lists `version`."""
    deadline = time.monotonic() + timeout_seconds
    while True:
        if is_version_published(pkg_name, version, pub_host=pub_host):
            print(f'{pkg_name} {version} is live on {pub_host}.', flush=True)
            return
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise SystemExit(
                f'Timed out after {timeout_seconds}s waiting for '
                f'{pkg_name} {version} to appear on {pub_host}.')
        time.sleep(min(poll_seconds, remaining))


def fetch_oidc_token(audience=PUB_HOST, environ=None):
    """Fetches a GitHub Actions OIDC JWT for `audience`, or falls back to
    `PUB_TOKEN` when already provided in `environ`."""
    env = os.environ if environ is None else environ
    request_url = env.get('ACTIONS_ID_TOKEN_REQUEST_URL')
    request_token = env.get('ACTIONS_ID_TOKEN_REQUEST_TOKEN')
    if request_url and request_token:
        separator = '&' if '?' in request_url else '?'
        url = f'{request_url}{separator}audience={urllib.parse.quote(audience, safe="")}'
        request = urllib.request.Request(
            url,
            headers={
                'Authorization': f'bearer {request_token}',
                'Accept': 'application/json; api-version=2.0',
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode('utf-8'))
        token = payload.get('value')
        if not token:
            raise SystemExit('GitHub OIDC token response contained no "value" field.')
        if env.get('GITHUB_ACTIONS') == 'true':
            print(f'::add-mask::{token}', flush=True)
        return token
    existing = env.get('PUB_TOKEN')
    if existing:
        return existing
    raise SystemExit(
        'Cannot authenticate with pub.dev: neither GitHub Actions OIDC '
        '(ACTIONS_ID_TOKEN_REQUEST_URL / ACTIONS_ID_TOKEN_REQUEST_TOKEN) '
        'nor PUB_TOKEN is set.')


def publish_package(root, folder, token):
    """Publishes `root / folder` to pub.dev using `token`."""
    env = os.environ.copy()
    env['PUB_TOKEN'] = token
    result = subprocess.run(flutter_publish(), cwd=root / folder, env=env,
                            capture_output=True, encoding='utf-8',
                            errors='replace')
    output = result.stdout + result.stderr
    print(output, end='' if output.endswith('\n') else '\n', flush=True)
    if result.returncode != 0:
        raise SystemExit(f'{folder}: flutter pub publish failed (exit {result.returncode}).')


def run_publish(selected, ref, dry_run, core_wait_timeout=180):
    version = verify_versions_and_tag(ref, dry_run)
    print(f'Release version: {version} ({"dry-run" if dry_run else "publish"})',
          flush=True)
    with tempfile.TemporaryDirectory(prefix='mediapipe-release-') as tmp:
        root = Path(tmp)
        for folder in package_folders():
            prepare(folder, root)
        validate_staged(root, selected)
        if dry_run:
            print(f'Dry run succeeded for {len(selected)} '
                  f'package{"" if len(selected) == 1 else "s"}.', flush=True)
            return
        pending = []
        for folder in selected:
            name = package_name(folder)
            if is_version_published(name, version):
                print(f'{name} {version} is already published on {PUB_HOST}; skipping.',
                      flush=True)
            else:
                pending.append(folder)
        if not pending:
            print(f'Every selected package is already at {version} on {PUB_HOST}.',
                  flush=True)
            return
        token = fetch_oidc_token()
        env = os.environ.copy()
        env['PUB_TOKEN'] = token
        subprocess.run(dart_token_add(), cwd=REPO, env=env, check=True)
        has_families = any(folder != CORE for folder in pending)
        for index, folder in enumerate(pending):
            name = package_name(folder)
            print(f'Publishing {name} {version} ({folder})...', flush=True)
            fresh_token = token if index == 0 else fetch_oidc_token()
            publish_package(root, folder, fresh_token)
            if folder == CORE and has_families:
                wait_for_version(name, version, timeout_seconds=core_wait_timeout)
        print(f'Published {len(pending)} package{"" if len(pending) == 1 else "s"} '
              f'at {version} to {PUB_HOST}.', flush=True)


def main(argv=None):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('packages', nargs='*', default=[],
                        help='Package folders or pubspec names (default: all, core first)')
    parser.add_argument('--dry-run', action='store_true',
                        default=os.environ.get('DRY_RUN', '').lower() == 'true',
                        help='Validate and dry-run without uploading to pub.dev')
    parser.add_argument('--ref', default=os.environ.get('GITHUB_REF', ''),
                        help='Git ref (default: $GITHUB_REF)')
    parser.add_argument('--core-wait-timeout', type=int, default=180,
                        help='Seconds to wait for mediapipe_core on pub.dev before families')
    args = parser.parse_args(argv)
    raw_packages = args.packages or [os.environ.get('PACKAGES', 'all')]
    selected = resolve_packages(raw_packages)
    run_publish(selected, args.ref, args.dry_run,
                core_wait_timeout=args.core_wait_timeout)


if __name__ == '__main__':
    main()

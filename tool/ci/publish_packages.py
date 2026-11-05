"""Prepares, validates and publishes the repository's packages to pub.dev.

Every package shares one version (`tool/check_repository.py`), and the task
families depend on `mediapipe_core` by that version. When a GitHub Release is
published (or the workflow is dispatched with a target version):

1. `prepare_release_version` reads the target version from `--version` or tag
   `refs/tags/v<version>`. When the repository's `pubspec.yaml` files are on an
   older version, it updates `version:` across all six `pubspec.yaml` files,
   `mediapipe_core: ^<version>` across the five family `pubspec.yaml` files,
   the dependency constraints in the READMEs, and ensures each package's
   `CHANGELOG.md` has a `## <version>` section.
2. Checks that every package's `pubspec.yaml` and `CHANGELOG.md` name the same
   version.
3. Copies every package outside the repository as `publish_check.py` does and
   runs `flutter pub publish --dry-run` on each selected package, refusing to
   proceed unless every package validates with zero warnings.
4. With `--prepare` or `--dry-run`, stops there.
5. Otherwise commits any version bump, pushes it to the target branch and tag
   `refs/tags/v<version>`, registers `PUB_TOKEN` with `dart pub token add
   https://pub.dev --env-var PUB_TOKEN`, mints a fresh GitHub Actions OIDC
   token for audience `https://pub.dev` before each upload, publishes
   `mediapipe_core` first, waits for pub.dev to list the new `mediapipe_core`
   version, and then publishes the five task family packages in order. Any
   package whose target version is already on pub.dev is skipped so a retried
   run finishes cleanly.
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
SEMVER = re.compile(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$')
VERSION_DOCS = [
    'README.md',
    'doc/guides/vision/object_detector.md',
]


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


def normalize_version(raw):
    """Strips an optional leading `v` and validates semantic version syntax."""
    cleaned = raw.strip()
    if cleaned.startswith('refs/tags/'):
        cleaned = cleaned[len('refs/tags/'):]
    if cleaned.startswith('v'):
        cleaned = cleaned[1:]
    if not SEMVER.match(cleaned):
        raise SystemExit(f'Invalid semantic version: {raw!r}')
    return cleaned


def target_version_from(ref, explicit_version=''):
    """Resolves the target release version from `explicit_version` or a
    `refs/tags/v<version>` ref, or returns `None` when neither is given."""
    if explicit_version and explicit_version.strip():
        return normalize_version(explicit_version)
    if ref and ref.startswith('refs/tags/'):
        tag = ref[len('refs/tags/'):]
        if not tag.startswith('v'):
            raise SystemExit(f'Release tag {ref!r} must start with "v" (e.g. v0.1.0).')
        return normalize_version(tag)
    return None


def read_pubspec_versions(packages_dir=PACKAGES, folders=None):
    """Returns `{folder: version}` across all packages and verifies they agree."""
    folders = package_folders() if folders is None else folders
    versions = {}
    for folder in folders:
        pubspec = (packages_dir / folder / 'pubspec.yaml').read_text(encoding='utf-8')
        match = re.search(r'^version:\s*(\S+)$', pubspec, re.M)
        if not match:
            raise SystemExit(f'packages/{folder}/pubspec.yaml has no version field.')
        versions[folder] = match.group(1)
    unique = sorted(set(versions.values()))
    if len(unique) != 1:
        raise SystemExit(f'Package versions do not agree: {versions}')
    return versions, unique[0]


def prepare_release_version(target_version, release_notes='', repo_root=REPO,
                            packages_dir=PACKAGES, folders=None):
    """Updates every package's `pubspec.yaml`, `CHANGELOG.md`, and README
    version constraints to `target_version` when needed. Returns True if any
    file was modified."""
    folders = package_folders() if folders is None else folders
    _, current_version = read_pubspec_versions(packages_dir=packages_dir, folders=folders)
    if not target_version:
        return False
    target_version = normalize_version(target_version)
    changed = False

    for folder in folders:
        pubspec_path = packages_dir / folder / 'pubspec.yaml'
        pubspec = pubspec_path.read_text(encoding='utf-8')
        updated = re.sub(r'^version:\s*\S+$', f'version: {target_version}',
                         pubspec, count=1, flags=re.M)
        if folder != CORE:
            updated = re.sub(r'^(\s*mediapipe_core:\s*)\^\S+$',
                             rf'\g<1>^{target_version}',
                             updated, count=1, flags=re.M)
        if updated != pubspec:
            pubspec_path.write_text(updated, encoding='utf-8')
            changed = True

        changelog_path = packages_dir / folder / 'CHANGELOG.md'
        changelog = changelog_path.read_text(encoding='utf-8')
        if not re.search(rf'^## {re.escape(target_version)}\b', changelog, re.M):
            notes = (release_notes or '').strip() or f'Release {target_version}.'
            changelog_path.write_text(
                f'## {target_version}\n\n{notes}\n\n{changelog}',
                encoding='utf-8')
            changed = True

    if target_version != current_version:
        doc_paths = [
            *(repo_root / rel for rel in VERSION_DOCS if (repo_root / rel).is_file()),
            *(packages_dir / folder / 'README.md' for folder in folders
              if (packages_dir / folder / 'README.md').is_file()),
        ]
        pattern = re.compile(
            rf'\b(mediapipe_[a-z_]+:\s*)\^{re.escape(current_version)}\b')
        for doc_path in doc_paths:
            text = doc_path.read_text(encoding='utf-8')
            updated = pattern.sub(rf'\g<1>^{target_version}', text)
            if updated != text:
                doc_path.write_text(updated, encoding='utf-8')
                changed = True

    if changed:
        print(f'Updated package versions from {current_version} to {target_version}.',
              flush=True)
    return changed


def verify_versions_and_tag(ref, dry_run, explicit_version='',
                            packages_dir=PACKAGES, folders=None):
    """Checks that every package's pubspec and CHANGELOG agree on the release
    version, and that a real publish has a matching tag or explicit version."""
    folders = package_folders() if folders is None else folders
    _, version = read_pubspec_versions(packages_dir=packages_dir, folders=folders)
    for folder in folders:
        changelog = (packages_dir / folder / 'CHANGELOG.md').read_text(encoding='utf-8')
        if not re.search(rf'^## {re.escape(version)}\b', changelog, re.M):
            raise SystemExit(
                f'packages/{folder}/CHANGELOG.md has no "## {version}" section.')
    expected_ref = f'refs/tags/v{version}'
    if ref and ref.startswith('refs/tags/') and ref != expected_ref:
        raise SystemExit(
            f'Tag ref {ref!r} does not match pubspec version {version} '
            f'(expected {expected_ref!r}).')
    target = target_version_from(ref, explicit_version)
    if target is not None and target != version:
        raise SystemExit(
            f'Target version {target} does not match pubspec version {version}.')
    if not dry_run and ref != expected_ref and not explicit_version:
        raise SystemExit(
            f'Refusing to publish version {version} from ref {ref!r}: '
            f'publishing requires tag ref {expected_ref!r} or --version {version}.')
    return version


def commit_and_tag_release(version, target_branch='main', repo_root=REPO):
    """Commits any modified version/changelog files, pushes the commit to
    `target_branch` (best-effort if branch-protected), and pushes tag
    `v<version>` to `origin`."""
    status = subprocess.run(
        ['git', 'status', '--porcelain', '--untracked-files=no'],
        cwd=repo_root, check=True, capture_output=True, text=True).stdout.strip()
    tag = f'v{version}'
    if status:
        subprocess.run(['git', 'config', 'user.name', 'github-actions[bot]'],
                       cwd=repo_root, check=True)
        subprocess.run(
            ['git', 'config', 'user.email',
             '41898282+github-actions[bot]@users.noreply.github.com'],
            cwd=repo_root, check=True)
        subprocess.run(['git', 'commit', '-am', f'chore(release): {tag}'],
                       cwd=repo_root, check=True)
        if target_branch and not target_branch.startswith('v'):
            push_branch = subprocess.run(
                ['git', 'push', 'origin', f'HEAD:refs/heads/{target_branch}'],
                cwd=repo_root, capture_output=True, text=True)
            if push_branch.returncode != 0:
                print(f'::warning::Could not push release commit directly to '
                      f'{target_branch}: {push_branch.stderr.strip()}', flush=True)
        subprocess.run(['git', 'tag', '-f', tag, 'HEAD'], cwd=repo_root, check=True)
        subprocess.run(['git', 'push', '--force', 'origin', f'refs/tags/{tag}'],
                       cwd=repo_root, check=True)
        print(f'Committed version {version} and updated tag {tag}.', flush=True)
        return
    # Even if files were already at `version`, ensure the tag exists on origin
    # when triggered with an explicit `--version`.
    existing = subprocess.run(
        ['git', 'rev-parse', '-q', '--verify', f'refs/tags/{tag}'],
        cwd=repo_root, capture_output=True, text=True)
    if existing.returncode != 0:
        subprocess.run(['git', 'tag', tag, 'HEAD'], cwd=repo_root, check=True)
        subprocess.run(['git', 'push', 'origin', f'refs/tags/{tag}'],
                       cwd=repo_root, check=True)
        print(f'Created and pushed tag {tag}.', flush=True)


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


def run_publish(selected, ref, dry_run, explicit_version='', release_notes='',
                target_branch='main', core_wait_timeout=180):
    target = target_version_from(ref, explicit_version)
    if target:
        prepare_release_version(target, release_notes=release_notes)
    version = verify_versions_and_tag(ref, dry_run, explicit_version=explicit_version)
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
        commit_and_tag_release(version, target_branch=target_branch)
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
    parser.add_argument('--prepare', action='store_true',
                        help='Update pubspec.yaml, CHANGELOG.md and README versions in place and exit')
    parser.add_argument('--dry-run', action='store_true',
                        default=os.environ.get('DRY_RUN', '').lower() == 'true',
                        help='Validate and dry-run without uploading to pub.dev')
    parser.add_argument('--version', default=os.environ.get('RELEASE_VERSION', ''),
                        help='Target version (default: $RELEASE_VERSION or inferred from tag)')
    parser.add_argument('--release-notes', default=os.environ.get('RELEASE_NOTES', ''),
                        help='Release notes for new CHANGELOG sections (default: $RELEASE_NOTES)')
    parser.add_argument('--target-branch', default=os.environ.get('TARGET_BRANCH', 'main'),
                        help='Branch to push version bump commits to (default: main)')
    parser.add_argument('--ref', default=os.environ.get('GITHUB_REF', ''),
                        help='Git ref (default: $GITHUB_REF)')
    parser.add_argument('--core-wait-timeout', type=int, default=180,
                        help='Seconds to wait for mediapipe_core on pub.dev before families')
    args = parser.parse_args(argv)
    if args.prepare:
        target = target_version_from(args.ref, args.version)
        if target:
            prepare_release_version(target, release_notes=args.release_notes)
        verify_versions_and_tag(args.ref, dry_run=True, explicit_version=args.version)
        return
    raw_packages = args.packages or [os.environ.get('PACKAGES', 'all')]
    selected = resolve_packages(raw_packages)
    run_publish(selected, args.ref, args.dry_run,
                explicit_version=args.version,
                release_notes=args.release_notes,
                target_branch=args.target_branch,
                core_wait_timeout=args.core_wait_timeout)


if __name__ == '__main__':
    main()

"""Builds a fresh app from what pub.dev would receive, for each target.

publish_check.py validates each package's archive; this tool builds against
its contents. Each package is copied outside the repository as publish_check
does, `flutter pub publish --dry-run` lists the files pub would archive, and
exactly those files are staged as the package `flutter pub get` would unpack
from pub.dev. A scratch app that depends on the six staged packages, with
every family's library imported, then builds for each target, so a
`.pubignore` line that drops a file a hook or a library needs, or a file only
the checkout provides, fails here instead of on a user's first install.

The staged families name mediapipe_core by version, as their archives do; the
app overrides it with the staged core, as pub.dev will resolve it once core is
published. Nothing is published.

Targets: macos, linux, windows, web, android and ios, each built as the
samples are in CI. The default is this host's desktop and the web. Android
needs the NDK the hooks compile the bridges with; iOS and macOS need Xcode.
"""
import argparse
from pathlib import Path
import platform
import re
import shutil
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'packages/mediapipe-core/tool'))
from consumer_packages import (  # noqa: E402
    configure_macos, consumer_environment, core_hook_defines)
from families import package_folders, package_name  # noqa: E402
from publish_check import archive_files, dry_run, prepare  # noqa: E402
from tool_helpers import run as run_logged  # noqa: E402

NAME = 'mediapipe_archives'
BUILDS = {
    'macos': ['flutter', 'build', 'macos', '--release'],
    'linux': ['flutter', 'build', 'linux', '--release'],
    'windows': ['flutter', 'build', 'windows', '--release'],
    'web': ['flutter', 'build', 'web', '--release'],
    'android': ['flutter', 'build', 'apk', '--release'],
    'ios': ['flutter', 'build', 'ios', '--release', '--no-codesign'],
}
HOST = {'Darwin': 'macos', 'Linux': 'linux', 'Windows': 'windows'}


def run(command, cwd, log, timeout=2400):
    return run_logged(command, cwd, log, env=consumer_environment(), timeout=timeout)


def stage(root):
    """Copies every package out of the repository, lists each archive with
    the dry run and stages exactly those files under `root/packages`."""
    staged = root / 'packages'
    # The copies live outside the repository, as publish_check.py keeps them:
    # under the checkout, its .gitignore (`build/`) would hide every file
    # from pub, which then lists an empty package.
    with tempfile.TemporaryDirectory(prefix='mediapipe-archives-') as tmp:
        copies = Path(tmp)
        for folder in package_folders():
            prepare(folder, copies)
        for folder in package_folders():
            files = archive_files(dry_run(copies / folder))
            for relative in files:
                source = copies / folder / relative
                if not source.is_file():
                    raise RuntimeError(f'{folder}: the dry run lists '
                                       f'{relative}, which the copy lacks.')
                destination = staged / folder / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
            print(f'{folder}: staged {len(files)} files', flush=True)
    return staged


def create_app(root, staged, targets):
    app = root / 'app'
    run(['flutter', 'create', '--empty', '--no-pub',
         '--platforms=' + ','.join(targets), '--project-name', NAME, app],
        REPO, root / 'create.log')
    names = [package_name(folder) for folder in package_folders()]
    dependencies = ''.join(f'  {name}:\n    path: ../packages/{folder}\n'
                           for name, folder in zip(names, package_folders()))
    defines = core_hook_defines()
    hooks = f'hooks:\n  user_defines:\n{defines}' if defines else ''
    (app / 'pubspec.yaml').write_text(f'''name: {NAME}
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
{dependencies}dependency_overrides:
  mediapipe_core:
    path: ../packages/mediapipe-core
{hooks}''', encoding='utf-8')
    # Every library compiles into the app; the build is the check.
    imports = ''.join(f"import 'package:{name}/{name}.dart';\n" for name in names)
    (app / 'lib/main.dart').write_text(f'{imports}\nvoid main() {{}}\n',
                                       encoding='utf-8')
    if 'macos' in targets:
        # Google's macOS runtimes are arm64 only, from macOS 14.
        configure_macos(app, deployment_target='14.0')
    if 'android' in targets:
        # Google's Android libraries need API 28, as the hooks require.
        gradle = app / 'android/app/build.gradle.kts'
        gradle.write_text(re.sub(r'minSdk = .*', 'minSdk = maxOf(28, flutter.minSdkVersion)',
                                 gradle.read_text(encoding='utf-8')), encoding='utf-8')
    return app


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('targets', nargs='*', choices=[*BUILDS, []], metavar='TARGET',
                        help=f'{", ".join(BUILDS)}; default: this desktop and web')
    parser.add_argument('--scratch', type=Path,
                        help='Folder for the copies, the app and the logs '
                             '(default: a new folder under build/ci-tmp)')
    args = parser.parse_args()
    targets = args.targets or [HOST[platform.system()], 'web']
    if args.scratch:
        root = args.scratch.resolve()
        root.mkdir(parents=True, exist_ok=True)
    else:
        build = REPO / 'build/ci-tmp'
        build.mkdir(parents=True, exist_ok=True)
        root = Path(tempfile.mkdtemp(prefix='archives-', dir=build))
    print(f'Artifacts: {root}', flush=True)
    staged = stage(root)
    app = create_app(root, staged, targets)
    run(['flutter', 'pub', 'get'], app, root / 'pub.log')
    for target in targets:
        run(BUILDS[target], app, root / f'build-{target}.log')
        print(f'{target}: built from the archives', flush=True)
    print(f'The archives build for {", ".join(targets)}: {root}', flush=True)


if __name__ == '__main__':
    main()

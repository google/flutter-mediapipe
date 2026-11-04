"""Copy a package the way a pub.dev consumer receives it, for fresh-app tests.

Only tracked files are copied, minus what the package's `.pubignore` keeps out
of the published archive (tests, tools, benchmarks, local builds, downloaded
models and maintainer files), so this copy and the published package cannot
drift apart. Examples are left out too: an app never receives them as code.
The fresh consumer tests then fail the way an app would if a declared asset,
native source, hook or pin were missing.
"""
import fnmatch
import json
import os
import platform
import shutil
import subprocess
from pathlib import Path

CORE = Path(__file__).resolve().parents[1]


def _published_exclusions(source: Path):
    """The root-anchored patterns in the package's `.pubignore` (`/name`)."""
    ignore = source / '.pubignore'
    lines = ignore.read_text().splitlines() if ignore.exists() else []
    return {line.strip().strip('/') for line in lines if line.startswith('/')}


def copy_package(source: Path, target: Path):
    """Copies [source]'s tracked files to [target] as pub.dev would ship them."""
    excluded = _published_exclusions(source) | {'build', 'models'}
    listed = subprocess.run(['git', 'ls-files', '-z', '--', '.'], cwd=source,
                            check=True, capture_output=True).stdout.decode()
    for relative in filter(None, listed.split('\0')):
        top = relative.split('/', 1)[0]
        # pub leaves out hidden files, such as .gitignore and .metadata.
        if any(part.startswith('.') for part in relative.split('/')):
            continue
        if top.startswith('example') or any(
                fnmatch.fnmatch(top, pattern) or fnmatch.fnmatch(relative, pattern)
                for pattern in excluded):
            continue
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / relative, destination)


def core_hook_defines():
    """A fresh app's `hooks.user_defines` entry for `mediapipe_core`.

    The hooks download Google's per-family libraries as an app's would,
    unless `MEDIAPIPE_ASSET_SOURCE` names a local folder holding them by
    SHA-256 (offline runs).
    """
    source = os.environ.get('MEDIAPIPE_ASSET_SOURCE')
    if not source:
        return ''
    return f'    mediapipe_core:\n      asset_source: {Path(source).resolve()}\n'


def configure_macos(app: Path, deployment_target=None):
    """Builds the fresh app arm64-only, as Google's macOS runtimes are (Flutter
    defaults release builds to a universal binary), and raises its deployment
    target when the runtime needs a newer macOS than Flutter's 10.15."""
    config = app / 'macos/Runner/Configs/AppInfo.xcconfig'
    settings = config.read_text()
    if 'EXCLUDED_ARCHS = x86_64' not in settings:
        config.write_text(settings + '\nARCHS = arm64\nEXCLUDED_ARCHS = x86_64\n')
    if deployment_target:
        project = app / 'macos/Runner.xcodeproj/project.pbxproj'
        project.write_text(project.read_text().replace(
            'MACOSX_DEPLOYMENT_TARGET = 10.15;',
            f'MACOSX_DEPLOYMENT_TARGET = {deployment_target};'))


def consumer_environment(**extra):
    """The environment a fresh app's commands run in.

    `MEDIAPIPE_ASSET_SOURCE` reaches the hooks through the pubspec
    ([core_hook_defines]), not the environment, so models the app's own
    commands fetch still come from Google, as an app's would.
    """
    env = {**os.environ, **extra}
    env.pop('MEDIAPIPE_ASSET_SOURCE', None)
    return env


def family_runtime(family, target):
    """Google's library for [family] on [target], as core's `familyRuntimes`
    pins it: `{family, target, file, sha256, url}`."""
    dart = shutil.which('dart.bat' if platform.system() == 'Windows' else 'dart')
    output = subprocess.run([dart or 'dart', 'run', 'tool/runtime_inventory.dart'],
                            cwd=CORE, check=True, capture_output=True, text=True).stdout
    for entry in json.loads(output[output.index('['):]):
        if entry['family'] == family and entry['target'] == target:
            return entry
    raise KeyError(f'No {family} library for {target}')

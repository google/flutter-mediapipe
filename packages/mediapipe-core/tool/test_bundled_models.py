"""Bundle models into a fresh Flutter app on this host, then run it offline.

Copies the packages as pub.dev ships them into a new app that lists one model
per family in its pubspec, and runs `dart run mediapipe_core:bundle_models`,
which downloads them from Google on this host. It then checks the folder, has
the command repair a corrupted copy and remove a stale one, and runs the app's
integration test: the bundled models must work with no network, a model that
is not bundled must be refused, and with downloads turned on that model must
download at run time. Finally a release build must ship exactly the bundled
models and pass the offline checks from a copy of its bundle.

CI runs it on the Linux x64 (under xvfb-run) and Windows x64 runners; it runs
on macOS arm64 as well.
"""
import json
from pathlib import Path
import platform
import re
import shutil
import sys
import tempfile

CORE = Path(__file__).resolve().parents[1]
PACKAGES = CORE.parent
REPO = PACKAGES.parent
TEMPLATES = CORE / 'tool/bundled_models'
sys.path.insert(0, str(CORE / 'tool'))
from consumer_packages import (  # noqa: E402
    configure_macos, consumer_environment, copy_package, core_hook_defines)
from tool_helpers import digest  # noqa: E402
from tool_helpers import run as run_logged  # noqa: E402
from families import task_families  # noqa: E402

NAME = 'mediapipe_bundled_models'
# One model per family: its package folder and its name in XxxModels.byName,
# in core's `bundlableFamilies` order. The checks also use Face Landmarker,
# which stays unbundled. Decision and Retrieval list the same EmbeddingGemma 2
# (388 MB), which the app bundles once.
FAMILIES = {
    'mediapipe_vision': ('mediapipe-task-vision', 'face_detector'),
    'mediapipe_text': ('mediapipe-task-text', 'language_detector'),
    'mediapipe_audio': ('mediapipe-task-audio', 'yamnet'),
    'mediapipe_decision': ('mediapipe-task-decision', 'embedding_gemma_2_text_vision'),
    'mediapipe_retrieval': ('mediapipe-task-retrieval', 'embedding_gemma_2_text_vision'),
}
SHA_NAME = re.compile(r'[0-9a-f]{64}')
MODEL_SUFFIXES = ('.tflite', '.task', '.litertlm')


def run(command, cwd, log, expect=0, timeout=1800):
    """Runs `command` as a consumer app's shell would, its output in `log`."""
    return run_logged(command, cwd, log, env=consumer_environment(), expect=expect,
                      timeout=timeout)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def expected_labels():
    """The manifest's labels. Families that list a model by the same name
    pin it identically (tool/check_repository.py), and the command keeps one
    copy, labeled by the first family that lists it."""
    labels = {}
    for family, (_, name) in FAMILIES.items():
        labels.setdefault(name, f'{family}: {name}')
    return set(labels.values())


def bundled_models(folder):
    """The manifest's models by label, after checking that the folder holds
    exactly those files, each named by its SHA-256."""
    manifest = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
    models = {entry['model']: entry['file'] for entry in manifest['models']}
    require(set(models) == expected_labels(), f'The manifest lists {sorted(models)}.')
    files = {path.name for path in folder.iterdir() if path.name != 'manifest.json'}
    require(files == set(models.values()), f'{folder} holds {sorted(files)}.')
    for name in files:
        require(digest(folder / name) == name, f'{name} does not match its name.')
    return models


def create_app(root, target):
    for package in ['mediapipe-core', *(folder for folder, _ in FAMILIES.values())]:
        copy_package(PACKAGES / package, root / 'packages' / package)
    app = root / 'app'
    run(['flutter', 'create', '--empty', '--no-pub', '--platforms=' + target,
         '--project-name', NAME, app], REPO, root / 'create.log')
    dependencies = ''.join(f'  {family}:\n    path: ../packages/{folder}\n'
                           for family, (folder, _) in FAMILIES.items())
    models = ''.join(f'    {family}:\n      models: [{name}]\n'
                     for family, (_, name) in FAMILIES.items())
    (app / 'pubspec.yaml').write_text(f'''name: {NAME}
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  crypto: ^3.0.6
  mediapipe_core:
    path: ../packages/mediapipe-core
{dependencies}dependency_overrides:
  mediapipe_core:
    path: ../packages/mediapipe-core
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
flutter:
  assets:
    - assets/mediapipe/
    - assets/test/
hooks:
  user_defines:
{models}{core_hook_defines()}''', encoding='utf-8')
    for template, destination in [('checks.dart', 'lib/checks.dart'),
                                  ('main.dart', 'lib/main.dart'),
                                  ('bundled_models_test.dart',
                                   'integration_test/bundled_models_test.dart')]:
        (app / destination).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(TEMPLATES / f'{template}.template', app / destination)
    (app / 'assets/test').mkdir(parents=True)
    shutil.copyfile(PACKAGES / 'mediapipe-task-vision/test/fixtures/face_detection/portrait-301x209.rgb',
                    app / 'assets/test/portrait.rgb')
    if target == 'macos':
        # Google's macOS runtimes are arm64 only, from macOS 14.
        configure_macos(app, deployment_target='14.0')
        # Only the debug run downloads; the release build stays without it.
        entitlements = app / 'macos/Runner/DebugProfile.entitlements'
        entitlements.write_text(entitlements.read_text().replace(
            '</dict>', '\t<key>com.apple.security.network.client</key>\n\t<true/>\n</dict>'))
    return app


def release_bundle(app, target):
    """The release build's folder, its executable and its models folder."""
    if target == 'linux':
        bundle = app / 'build/linux/x64/release/bundle'
        executable = Path(NAME)
    elif target == 'windows':
        bundle = app / 'build/windows/x64/runner/Release'
        executable = Path(f'{NAME}.exe')
    else:
        bundle = app / f'build/macos/Build/Products/Release/{NAME}.app'
        executable = Path('Contents/MacOS') / NAME
    # A macOS framework reaches its resources through symlinks as well.
    folders = {path.parent.resolve() for path in bundle.rglob('manifest.json')
               if path.parent.parent.name == 'assets' and path.parent.name == 'mediapipe'}
    require(len(folders) == 1, f'{bundle} holds {len(folders)} model folders.')
    return bundle, executable, folders.pop()


def main():
    # Flutter emits Unicode build markers; Windows CI defaults to cp1252.
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    target = {'Linux': 'linux', 'Windows': 'windows', 'Darwin': 'macos'}.get(platform.system())
    machine = platform.machine().lower()
    if not ((target in ('linux', 'windows') and machine in ('amd64', 'x86_64'))
            or (target == 'macos' and machine == 'arm64')):
        raise SystemExit('This test needs Linux x64, Windows x64 or macOS arm64.')
    folders = sorted(folder for folder, _ in FAMILIES.values())
    require(folders == sorted(task_families().values()),
            f'FAMILIES covers {folders}; add a model for every task family.')
    build = REPO / 'build/ci-tmp'
    build.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix=f'bundled-{target}-', dir=build))
    print(f'Artifacts: {root}', flush=True)
    app = create_app(root, target)
    run(['flutter', 'pub', 'get'], app, root / 'pub.log')

    # Build time: the command downloads each listed model from Google here.
    log = run(['dart', 'run', 'mediapipe_core:bundle_models'], app, root / 'bundle.log')
    folder = app / 'assets/mediapipe'
    models = bundled_models(folder)
    for label in models:
        require(f'Downloaded: {label}' in log, f'{label} was not downloaded.')
    log = run(['dart', 'run', 'mediapipe_core:bundle_models', '--check'], app,
              root / 'check.log')
    require(f'assets/mediapipe/ matches pubspec.yaml: {len(expected_labels())} models' in log,
            'The check did not pass.')

    # A corrupted copy and an unlisted file fail the check; the command
    # replaces the first and removes the second.
    corrupted = folder / models['mediapipe_audio: yamnet']
    data = bytearray(corrupted.read_bytes())
    data[len(data) // 2] ^= 0xFF
    corrupted.write_bytes(bytes(data))
    stale = '0' * 64
    (folder / stale).write_bytes(b'no longer listed')
    log = run(['dart', 'run', 'mediapipe_core:bundle_models', '--check'], app,
              root / 'check-stale.log', expect=1)
    require('mediapipe_audio: yamnet is missing from assets/mediapipe/' in log and
            f'assets/mediapipe/{stale} is no longer listed' in log,
            'The check did not report the corrupted and the stale file.')
    log = run(['dart', 'run', 'mediapipe_core:bundle_models'], app, root / 'repair.log')
    require('Downloaded: mediapipe_audio: yamnet' in log and
            f'Removed assets/mediapipe/{stale}' in log, 'The command did not repair the folder.')
    require(bundled_models(folder) == models, 'The repaired folder differs.')
    run(['dart', 'run', 'mediapipe_core:bundle_models', '--check'], app, root / 'check-repaired.log')

    # Run time, in a debug build.
    run(['flutter', 'test', '-d', target, 'integration_test/bundled_models_test.dart',
         '--reporter', 'expanded'], app, root / 'integration.log', timeout=2400)

    # A release build ships exactly the bundled models and no other model
    # file, and passes the offline checks from a copy of its bundle.
    run(['flutter', 'build', target, '--release'], app, root / 'build-release.log',
        timeout=2400)
    bundle, executable, shipped = release_bundle(app, target)
    files = {path.name for path in shipped.iterdir() if SHA_NAME.fullmatch(path.name)}
    require(files == set(models.values()), f'The release ships {sorted(files)}.')
    for name in files:
        require(digest(shipped / name) == name, f'The release copy of {name} differs.')
    strays = [path for path in bundle.rglob('*') if path.suffix in MODEL_SUFFIXES]
    require(not strays, f'The release ships other model files: {strays}')
    deployed = root / 'deployed' / bundle.name
    shutil.copytree(bundle, deployed, symlinks=True)
    log = run([deployed / executable], deployed, root / 'release.log', timeout=600)
    require('Bundled models passed in release.' in log, 'The release build did not pass.')

    report = {'target': target, 'models': {label: {'sha256': sha, 'bytes': (folder / sha).stat().st_size}
                                           for label, sha in models.items()}}
    (root / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Bundled models passed on {target}: {root}', flush=True)


if __name__ == '__main__':
    main()

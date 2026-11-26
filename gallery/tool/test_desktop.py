"""Build and exercise the actual CPU gallery on a Windows/Linux host."""
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

GALLERY = Path(__file__).resolve().parents[1]
REPO = GALLERY.parent
sys.path.insert(0, str(REPO / 'packages/mediapipe-core/tool'))
from consumer_packages import family_runtime  # noqa: E402
from families import task_families  # noqa: E402

# The journey's first-use models but Text-to-Speech's, which still downloads
# in the app, by the names their families' byName list.
PREFETCH = ['parakeet_tdt_v3', 'laya_s256', 'embedding_gemma_2_text',
            'embedding_gemma_2_text_vision']


def dart():
    """Dart's executable. On Windows, by its lower-case file name: shutil.which
    returns PATHEXT's `dart.EXE`, and `dart run` then starts the build hooks'
    compiler as `dart.EXE.exe`, which does not exist."""
    return (os.name == 'nt' and shutil.which('dart.exe')) or shutil.which('dart')


def model_store(target):
    """The gallery's model store, in path_provider's application support."""
    if target == 'linux':
        data = os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share'
        support = Path(data) / 'com.example.mediapipe_gallery'
    else:
        support = Path(os.environ['APPDATA']) / 'com.example/mediapipe_gallery'
    return support / 'mediapipe/models'


def main():
    # Flutter emits Unicode build markers; Windows CI defaults to cp1252.
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    target = {'Linux': 'linux', 'Windows': 'windows'}.get(platform.system())
    arch = {'amd64': 'x64', 'x86_64': 'x64', 'aarch64': 'arm64',
            'arm64': 'arm64'}.get(platform.machine().lower())
    if target is None or arch is None:
        raise SystemExit('Run this validation on Windows or Linux, on x64 or arm64.')
    evidence = REPO / f'build/ci-tmp/gallery-desktop-{target}'
    evidence.mkdir(parents=True, exist_ok=True)

    def run(args, name, timeout=1200):
        executable = shutil.which(str(args[0]))
        if executable is None:
            raise RuntimeError(f'Missing command: {args[0]}')
        print(f'{name}: {args}', flush=True)
        with (evidence / f'{name}.log').open('w', encoding='utf-8') as log:
            result = subprocess.run([executable, *map(str, args[1:])],
                                    cwd=GALLERY, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        if result.returncode:
            print((evidence / f'{name}.log').read_text(encoding='utf-8', errors='replace'),
                  flush=True)
            raise RuntimeError(f'{name} failed ({result.returncode})')

    run(['dart', 'run', REPO / 'tool/gallery_builder/bin/prepare_gallery.dart',
         '--target', f'{target}/{arch}'], 'prepare')
    manifest = json.loads((GALLERY / 'assets/manifest.json').read_text())
    required = {'face_landmarker', 'hand_landmarker', 'pose_landmarker',
                'audio_classifier', 'language_detector', 'text_classifier',
                'text_embedder'}
    if not required <= set(manifest['tasks']):
        raise RuntimeError(f'Missing gallery tasks: {sorted(required - set(manifest["tasks"]))}')
    run(['flutter', 'pub', 'get'], 'pub')
    # The journey downloads its first-use models when it starts, which took
    # up to 19 minutes on Linux x64 (November 20, 2026). They download here
    # instead, in the background into the app's own store, while the build
    # and the suites before the journey run; the app finds each one there or
    # waits for the one still downloading (tool/prefetch_models.dart).
    store = model_store(target)
    with (evidence / 'prefetch.log').open('w', encoding='utf-8') as log:
        prefetch = subprocess.Popen(
            [dart(), 'run', 'tool/prefetch_models.dart',
             str(store), *PREFETCH],
            cwd=GALLERY, stdout=log, stderr=subprocess.STDOUT)
    # Its build hooks fetch the family runtimes into the folder the app's
    # build reuses, so the app's build starts once they are done.
    while (prefetch.poll() is None and 'MODEL_PREFETCH started' not in
           (evidence / 'prefetch.log').read_text(encoding='utf-8', errors='replace')):
        time.sleep(1)
    run(['flutter', 'analyze', 'lib', 'test',
         'integration_test/desktop_cpu_camera_test.dart',
         'integration_test/face_landmarker_still_image_test.dart',
         'integration_test/gallery_journey_test.dart',
         'integration_test/runtime_test.dart',
         'integration_test/task_models_test.dart',
         'integration_test/text_tasks_test.dart',
         'integration_test/audio_task_test.dart'], 'analyze')
    run(['flutter', 'test', 'test'], 'unit')
    for name in ['assets_test', 'runtime_test', 'text_tasks_test',
                 'audio_task_test', 'face_landmarker_still_image_test',
                 'task_models_test',
                 'gallery_journey_test']:
        # The journey first downloads every first-use model, each within its
        # own limit (gallery_journey_test.dart): up to 19 minutes on Linux
        # x64 (November 20, 2026), so it gets 40.
        run(['flutter', 'test', '-d', target,
             f'integration_test/{name}.dart', '--reporter', 'expanded'], name,
            timeout=2400 if name == 'gallery_journey_test' else 1200)
        if name == 'gallery_journey_test':
            check_prefetch(evidence, store, prefetch)
    for task in ['face', 'hand']:
        run(['flutter', 'test', '-d', target,
             'integration_test/desktop_cpu_camera_test.dart',
             f'--dart-define=GALLERY_LIVE_TASK={task}',
             '--reporter', 'expanded'], f'desktop_cpu_camera_test-{task}')
    run(['flutter', 'build', target, '--release'], 'release')
    bundle = GALLERY / (f'build/linux/{arch}/release/bundle' if target == 'linux'
                         else f'build/windows/{arch}/runner/Release')
    # One library per family, each the one core pins for this target.
    runtimes = {}
    for family in task_families():
        pin = family_runtime(family, f'{target}/{arch}')
        libraries = list(bundle.rglob(pin['file']))
        if len(libraries) != 1:
            raise RuntimeError(f'Expected one {family} library, got {libraries}')
        sha = hashlib.sha256(libraries[0].read_bytes()).hexdigest()
        if sha != pin['sha256']:
            raise RuntimeError(f'{libraries[0]} is not the pinned {family} library')
        runtimes[family] = {'file': str(libraries[0].relative_to(bundle)),
                            'sha256': sha}
    # The journey again in a release build (tool/ci/run_release_suite.py),
    # which rebuilds the bundle with the journey as its entry point.
    run([sys.executable, '-B', REPO / 'tool/ci/run_release_suite.py', '--target', target,
         '--suite', 'integration_test/gallery_journey_test.dart', '--timeout', '900'],
        'release-journey', timeout=1800)
    (evidence / 'report.json').write_text(json.dumps({
        'target': f'{target}/{arch}', 'delegates': ['cpu'], 'runtimes': runtimes,
        'checks': ['native-camera-registration-and-enumeration',
                   'assets', 'cross-task-runtime-coexistence',
                   'one-pinned-library-per-family',
                   'gallery-supplied-camera-rgba-bgra-switch-restart-cleanup',
                   'face-landmarker-still-image-inference-and-overlay',
                   'every-sidebar-task-gallery-journey',
                   'live-tasks-face-hand',
                   'release-build', 'every-sidebar-task-gallery-journey-release'],
        'physical_webcam_tested': False,
    }, indent=2) + '\n')
    print(f'CPU gallery validation passed: {evidence}', flush=True)


def check_prefetch(evidence, store, prefetch):
    """Warns when the prefetch failed, since the journey then downloaded
    those models itself, and fails when the app's store is not the folder
    the prefetch filled, since every later run would lose its head start."""
    if prefetch.wait() != 0:
        print('::warning::The model prefetch failed, so the journey '
              'downloaded those models itself:', flush=True)
    log = (evidence / 'prefetch.log').read_text(encoding='utf-8', errors='replace')
    print(log, flush=True)
    filled = set(re.findall(r'MODEL_PREFETCH \S+: ([0-9a-f]{16}) in', log))
    folders = store.iterdir() if store.is_dir() else []
    written = {entry.name for entry in folders if entry.is_dir()} - filled
    if not written:
        raise RuntimeError(f'The app stored no model in {store}, so it keeps its '
                           'models elsewhere: update model_store().')


if __name__ == '__main__':
    main()

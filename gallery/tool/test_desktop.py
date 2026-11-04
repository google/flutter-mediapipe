"""Build and exercise the actual CPU gallery on a Windows/Linux host."""
import hashlib
import json
import platform
from pathlib import Path
import shutil
import subprocess
import sys

GALLERY = Path(__file__).resolve().parents[1]
REPO = GALLERY.parent
sys.path.insert(0, str(REPO / 'packages/mediapipe-core/tool'))
from consumer_packages import family_runtime  # noqa: E402
from families import task_families  # noqa: E402


def main():
    # Flutter emits Unicode build markers; Windows CI defaults to cp1252.
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    target = {'Linux': 'linux', 'Windows': 'windows'}.get(platform.system())
    if target is None or platform.machine().lower() not in ('amd64', 'x86_64'):
        raise SystemExit('Run this validation on Windows x64 or Linux x64.')
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
         '--target', f'{target}/x64'], 'prepare')
    manifest = json.loads((GALLERY / 'assets/manifest.json').read_text())
    required = {'face_landmarker', 'hand_landmarker', 'pose_landmarker',
                'audio_classifier', 'language_detector', 'text_classifier',
                'text_embedder'}
    if not required <= set(manifest['tasks']):
        raise RuntimeError(f'Missing gallery tasks: {sorted(required - set(manifest["tasks"]))}')
    run(['flutter', 'pub', 'get'], 'pub')
    run(['flutter', 'analyze', 'lib', 'test',
         'integration_test/desktop_cpu_camera_test.dart',
         'integration_test/face_landmarker_still_image_test.dart',
         'integration_test/gallery_journey_test.dart',
         'integration_test/runtime_test.dart',
         'integration_test/text_tasks_test.dart',
         'integration_test/audio_task_test.dart'], 'analyze')
    run(['flutter', 'test', 'test'], 'unit')
    for name in ['assets_test', 'runtime_test', 'text_tasks_test',
                 'audio_task_test', 'face_landmarker_still_image_test',
                 'gallery_journey_test']:
        run(['flutter', 'test', '-d', target,
             f'integration_test/{name}.dart', '--reporter', 'expanded'], name)
    for task in ['face', 'hand']:
        run(['flutter', 'test', '-d', target,
             'integration_test/desktop_cpu_camera_test.dart',
             f'--dart-define=GALLERY_LIVE_TASK={task}',
             '--reporter', 'expanded'], f'desktop_cpu_camera_test-{task}')
    run(['flutter', 'build', target, '--release'], 'release')
    bundle = GALLERY / ('build/linux/x64/release/bundle' if target == 'linux'
                         else 'build/windows/x64/runner/Release')
    # One library per family, each the one core pins for this target.
    runtimes = {}
    for family in task_families():
        pin = family_runtime(family, f'{target}/x64')
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
        'target': f'{target}/x64', 'delegates': ['cpu'], 'runtimes': runtimes,
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


if __name__ == '__main__':
    main()

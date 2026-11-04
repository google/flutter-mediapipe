"""Validate official CPU references and isolated Flutter desktop consumers."""
import argparse
import json
from pathlib import Path
import platform
import shutil
import sys
import tempfile
import urllib.request
from urllib.parse import urlsplit

PACKAGE = Path(__file__).resolve().parents[1]
REPO = PACKAGE.parents[1]
sys.path.insert(0, str(PACKAGE.parent / 'mediapipe-core/tool'))
from consumer_packages import (  # noqa: E402
    consumer_environment, copy_package, core_hook_defines, family_runtime)
from model_pins import model_pins  # noqa: E402
from tool_helpers import digest, run  # noqa: E402


def download(url, sha, destination):
    if destination.exists() and digest(destination) == sha:
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=60) as response, destination.open('wb') as output:
        shutil.copyfileobj(response, output)
    if digest(destination) != sha:
        raise RuntimeError(f'Incorrect download: {destination}')


def main():
    # Flutter emits Unicode build markers; Windows CI defaults to cp1252.
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--object-detector', action='store_true')
    parser.add_argument('--image-tasks', action='store_true')
    parser.add_argument('--landmark-tasks', action='store_true')
    parser.add_argument('--segmenter-tasks', action='store_true')
    # Linux only: Google's Windows wheel lacks the stateful API, and its
    # library runs a stroke in about 25 s (upstream-issues.md UP-048).
    parser.add_argument('--interactive-segmenter', action='store_true')
    args = parser.parse_args()
    system = platform.system()
    target = {'Linux': 'linux', 'Windows': 'windows'}.get(system)
    if target is None or platform.machine().lower() not in ('amd64', 'x86_64'):
        raise SystemExit('This validation requires Linux x64 or Windows x64.')
    build = REPO / 'build/ci-tmp'
    build.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix=f'desktop-{target}-', dir=build))
    print(f'Validation artifacts: {root}', flush=True)
    pins = {urlsplit(pin['url']).path.rsplit('/', 1)[-1]: pin for pin in model_pins()
            if pin['source'].startswith('mediapipe-task-vision/')}
    models = ['blaze_face_short_range.tflite', 'face_landmarker.task']
    if args.object_detector:
        models.append('efficientdet_lite0.tflite')
    if args.image_tasks:
        models += ['efficientnet_lite0.tflite', 'mobilenet_v3_small.tflite']
    if args.landmark_tasks:
        models += ['hand_landmarker.task', 'gesture_recognizer.task',
                   'pose_landmarker_lite.task', 'holistic_landmarker.task']
    if args.segmenter_tasks:
        models.append('deeplab_v3.tflite')
    if args.interactive_segmenter:
        models.append('interactive_segmentation.task')
    for name in models:
        download(pins[name]['url'], pins[name]['sha256'], PACKAGE / 'models' / name)

    from cpu_reference import FACE_FILES, FACE_TASKS, generate
    references = root / 'reference'
    files = list(FACE_FILES)
    tasks = list(FACE_TASKS)
    if args.object_detector:
        tasks.append(('object_detector', 'object_detection'))
        files += ['object_detection/official_reference.json', 'object_detection/official_video_reference.json']
    if args.image_tasks:
        tasks.append(('image_tasks', 'image_tasks'))
        files.append('image_tasks/official_reference.json')
    if args.landmark_tasks:
        tasks.append(('landmark_tasks', 'landmark_tasks'))
        files.append('landmark_tasks/official_reference.json')
    if args.segmenter_tasks:
        tasks.append(('segmenter_tasks', 'segmenter_tasks'))
        files.append('segmenter_tasks/official_reference.json')
    oracle = generate(root, references, target + '/x64', tasks, files)
    library_sha = oracle['library_sha256']
    if args.interactive_segmenter:
        if target != 'linux':
            raise SystemExit('The stateful Interactive Segmenter is validated on Linux only '
                             '(upstream-issues.md UP-048).')
        # Rewrites the checked-in fixtures with this host's wheel, as above.
        run([oracle['python'], '-u', '-X', 'faulthandler', '-B',
             PACKAGE / 'tool/generate_interactive_segmenter_reference.py'],
            REPO, root / 'interactive_segmenter-reference.log')
    comparisons = oracle['comparisons']

    # Package copies exclude source builds, tools, caches and maintenance opt-ins.
    for name in ['mediapipe-core', 'mediapipe-task-vision']:
        copy_package(PACKAGE.parent / name, root / 'packages' / name)
    app = root / 'app'
    run(['flutter', 'create', '--empty', '--no-pub', '--platforms=' + target,
         '--project-name', 'mediapipe_desktop_smoke', app], REPO, root / 'create.log')
    # Every selected task is bundled, asset-mapped and exercised by the app.
    selected = ['face_detector', 'face_landmarker']
    bundled = [(PACKAGE / 'models/blaze_face_short_range.tflite', 'model.tflite'),
               (PACKAGE / 'models/face_landmarker.task', 'face_landmarker.task'),
               (PACKAGE / 'test/fixtures/face_detection/portrait-301x209.rgb', 'portrait.rgb')]
    if args.object_detector:
        selected.append('object_detector')
        bundled.append((PACKAGE / 'models/efficientdet_lite0.tflite', 'object_detector.tflite'))
    if args.image_tasks:
        selected += ['image_classifier', 'image_embedder']
        bundled += [(PACKAGE / 'models/efficientnet_lite0.tflite', 'image_classifier.tflite'),
                    (PACKAGE / 'models/mobilenet_v3_small.tflite', 'image_embedder.tflite')]
    if args.landmark_tasks:
        selected += ['hand_landmarker', 'gesture_recognizer', 'pose_landmarker',
                     'holistic_landmarker']
        landmarks = PACKAGE / 'test/fixtures/landmark_tasks'
        bundled += [(PACKAGE / 'models/hand_landmarker.task', 'hand_landmarker.task'),
                    (PACKAGE / 'models/gesture_recognizer.task', 'gesture_recognizer.task'),
                    (PACKAGE / 'models/pose_landmarker_lite.task', 'pose_landmarker.task'),
                    (PACKAGE / 'models/holistic_landmarker.task', 'holistic_landmarker.task'),
                    (landmarks / 'thumb_up.rgb', 'thumb_up.rgb'),
                    (landmarks / 'pose.rgb', 'pose.rgb')]
    if args.interactive_segmenter:
        selected.append('interactive_segmenter')
    if args.segmenter_tasks:
        selected += ['image_segmenter']
        bundled += [(PACKAGE / 'models/deeplab_v3.tflite', 'image_segmenter.tflite')]
    (app / 'pubspec.yaml').write_text('''name: mediapipe_desktop_smoke
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  mediapipe_vision:
    path: ../packages/mediapipe-task-vision
dependency_overrides:
  mediapipe_core:
    path: ../packages/mediapipe-core
dev_dependencies:
  crypto: ^3.0.6
  test: ^1.31.0
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
hooks:
  user_defines:
''' + core_hook_defines() + '''    mediapipe_vision:
      tasks: [''' + ', '.join(selected) + ''']
flutter:
  assets:
''' + ''.join(f'    - assets/{name}\n' for _, name in bundled))
    assets = app / 'assets'
    assets.mkdir()
    for source, name in bundled:
        shutil.copyfile(source, assets / name)
    shutil.copytree(PACKAGE / 'models', app / 'models',
                    ignore=shutil.ignore_patterns('*.xnnpack_cache'))
    for folder in ['fixtures/face_detection', 'fixtures/face_landmarker', 'support']:
        shutil.copytree(PACKAGE / 'test' / folder, app / 'test' / folder)
    for name in ['face_detector_test.dart', 'face_landmarker_test.dart', 'pixel_conversion_test.dart']:
        shutil.copyfile(PACKAGE / 'test' / name, app / 'test' / name)
    if args.object_detector:
        shutil.copytree(PACKAGE / 'test/fixtures/object_detection', app / 'test/fixtures/object_detection')
        shutil.copyfile(PACKAGE / 'test/object_detector_test.dart', app / 'test/object_detector_test.dart')
        shutil.copyfile(PACKAGE / 'test/capabilities_test.dart', app / 'test/capabilities_test.dart')
    if args.image_tasks:
        shutil.copytree(PACKAGE / 'test/fixtures/image_tasks', app / 'test/fixtures/image_tasks')
        shutil.copyfile(PACKAGE / 'test/image_tasks_test.dart', app / 'test/image_tasks_test.dart')
    if args.landmark_tasks:
        # The generator rewrote the raw fixtures with this host's decoder.
        shutil.copytree(PACKAGE / 'test/fixtures/landmark_tasks', app / 'test/fixtures/landmark_tasks')
        shutil.copyfile(PACKAGE / 'test/landmark_tasks_test.dart', app / 'test/landmark_tasks_test.dart')
    if args.interactive_segmenter:
        shutil.copytree(PACKAGE / 'test/fixtures/interactive_segmentation',
                        app / 'test/fixtures/interactive_segmentation')
        shutil.copyfile(PACKAGE / 'test/interactive_segmenter_test.dart',
                        app / 'test/interactive_segmenter_test.dart')
    if args.segmenter_tasks:
        # Both segmenter tasks reuse the checked-in face fixtures.
        shutil.copyfile(PACKAGE / 'test/segmenter_tasks_test.dart', app / 'test/segmenter_tasks_test.dart')
    if args.object_detector and args.image_tasks and args.landmark_tasks and args.segmenter_tasks:
        # Every camera-capable task, in VIDEO and LIVE_STREAM on this host's runtime.
        shutil.copyfile(PACKAGE / 'test/live_stream_runtime_test.dart',
                        app / 'test/live_stream_runtime_test.dart')
    (app / 'integration_test').mkdir()
    for source, destination in [('flutter_smoke_test.dart.template', 'integration_test/face_test.dart'),
                                ('flutter_release_smoke.dart.template', 'lib/main.dart')]:
        content = (PACKAGE / 'tool' / source).read_text().replace(
            'Delegate.values', 'const [Delegate.cpu]')
        if args.object_detector and destination == 'lib/main.dart':
            content = content.replace('      report(', '      await runObjectDetectorSmoke();\n      report(')
            content += (PACKAGE / 'tool/flutter_desktop_object_smoke.dart.template').read_text()
        if args.image_tasks and destination == 'lib/main.dart':
            content = content.replace('      report(', '      await runImageTasksSmoke();\n      report(')
            content += (PACKAGE / 'tool/flutter_desktop_image_smoke.dart.template').read_text()
        if args.landmark_tasks and destination == 'lib/main.dart':
            content = content.replace('      report(', '      await runLandmarkTasksSmoke();\n      report(')
            content += (PACKAGE / 'tool/flutter_desktop_landmark_smoke.dart.template').read_text()
        if args.segmenter_tasks and destination == 'lib/main.dart':
            content = content.replace('      report(', '      await runSegmenterTasksSmoke();\n      report(')
            content += (PACKAGE / 'tool/flutter_desktop_segmenter_smoke.dart.template').read_text()
        (app / destination).write_text(content)
    env = consumer_environment(MEDIAPIPE_CPU_REFERENCE_DIR=str(references))
    # Google's vision library, which the hook bundles unchanged on Linux and
    # Windows; the references come from its wheel's own library.
    vision = family_runtime('vision', target + '/x64')
    run(['flutter', 'pub', 'get'], app, root / 'pub.log', env)
    # Every selected task builds its own tasks per reference case. A task's
    # close waits for Google's usage-logging upload, so a slow reply holds a
    # test past the default 30 s (upstream-issues.md UP-025).
    run(['dart', 'test', '--timeout', '180s', '--reporter', 'expanded'], app,
        root / 'dart-tests.log', env, timeout=2400)
    run(['flutter', 'test', '-d', target, 'integration_test/face_test.dart',
         '--reporter', 'expanded'], app, root / 'integration.log', env)
    report = {'target': target + '/x64', 'delegate': 'CPU', 'library_sha256': vision['sha256'],
              'reference_library_sha256': library_sha,
              'reference_comparison': comparisons, 'modes': {}}
    for mode in ['debug', 'release']:
        run(['flutter', 'build', target, '--' + mode], app, root / f'build-{mode}.log', env)
        bundle = app / (f'build/linux/x64/{mode}/bundle' if target == 'linux' else
                        f'build/windows/x64/runner/{mode.capitalize()}')
        libraries = [path for path in bundle.rglob('*')
                     if path.is_file() and path.suffix in ('.so', '.dll')
                     and digest(path) == vision['sha256']]
        if len(libraries) != 1:
            raise RuntimeError(f"{mode} bundle must hold Google's vision library once: {libraries}")
        deployed = root / 'deployed' / mode
        shutil.copytree(bundle, deployed)
        executable = deployed / ('mediapipe_desktop_smoke.exe' if target == 'windows'
                                  else 'mediapipe_desktop_smoke')
        log = root / f'inference-{mode}.log'
        run([executable], deployed, log, env, timeout=300)
        if 'bundled cpu Face Detector and Face Landmarker inference passed.' not in log.read_text():
            raise RuntimeError(f'{mode} app did not confirm inference')
        if args.object_detector and 'Object Detector CPU inference passed.' not in log.read_text():
            raise RuntimeError(f'{mode} app did not confirm Object Detector inference')
        if args.image_tasks and 'Image Classifier and Image Embedder CPU inference passed.' not in log.read_text():
            raise RuntimeError(f'{mode} app did not confirm image task inference')
        if args.landmark_tasks and ('Hand, Gesture, Pose and Holistic Landmarker CPU inference '
                                    'passed.') not in log.read_text():
            raise RuntimeError(f'{mode} app did not confirm landmark task inference')
        if args.segmenter_tasks and 'Image Segmenter CPU inference passed.' not in log.read_text():
            raise RuntimeError(f'{mode} app did not confirm segmenter task inference')
        report['modes'][mode] = {'inference': 'passed',
                                 'bundled_libraries': [str(path.relative_to(bundle)) for path in libraries]}
    (root / 'report.json').write_text(json.dumps(report, indent=2))
    print(f'Linux/Windows CPU validation passed: {root}', flush=True)


if __name__ == '__main__':
    main()

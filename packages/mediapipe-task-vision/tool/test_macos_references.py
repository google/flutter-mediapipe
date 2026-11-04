"""Compare Google's vision library with the official wheel on this Mac.

Face, Hand, Pose, Gesture and Holistic Landmarker, Object Detector, Image
Classifier, Image Embedder and Image Segmenter run on the CPU. Each is
compared with the official wheel's output, generated on this machine: the
wheel's CPU results drift between Apple CPUs, as cpu_reference.py records for
every native job. Metal is withdrawn while Google's library since 1.1.1 gives
different results there from its 1.1.0 wheel (upstream-issues.md UP-057);
prepare_gpu_reference.py still writes the macOS Metal references for when it
returns.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil

from cpu_reference import FACE_FILES, FACE_TASKS, generate, install
from consumer_packages import core_hook_defines
from tool_helpers import run

PACKAGE = Path(__file__).resolve().parents[1]
REPO = PACKAGE.parents[1]



def test_root(root):
    (root / 'test').mkdir(parents=True, exist_ok=True)
    for folder in ('support', 'fixtures/face_detection',
                   'fixtures/face_landmarker', 'fixtures/landmark_tasks',
                   'fixtures/image_tasks', 'fixtures/object_detection',
                   'fixtures/segmenter_tasks'):
        shutil.copytree(PACKAGE / 'test' / folder, root / 'test' / folder,
                        dirs_exist_ok=True)
    shutil.copyfile(PACKAGE / 'test/face_landmarker_test.dart',
                    root / 'test/face_landmarker_test.dart')
    for name in ('landmark_tasks_test.dart', 'image_tasks_test.dart',
                 'object_detector_test.dart', 'segmenter_tasks_test.dart'):
        shutil.copyfile(PACKAGE / 'test' / name, root / 'test' / name)
    (root / 'models').mkdir(exist_ok=True)
    shutil.copyfile(PACKAGE / 'models/blaze_face_short_range.tflite',
                    root / 'models/blaze_face_short_range.tflite')
    shutil.copyfile(PACKAGE / 'models/face_landmarker.task',
                    root / 'models/face_landmarker.task')
    for name in ('hand_landmarker.task', 'pose_landmarker_lite.task',
                 'gesture_recognizer.task', 'holistic_landmarker.task',
                 'efficientdet_lite0.tflite', 'efficientnet_lite0.tflite',
                 'mobilenet_v3_small.tflite', 'deeplab_v3.tflite'):
        shutil.copyfile(PACKAGE / 'models' / name, root / 'models' / name)
    (root / 'pubspec.yaml').write_text(f'''name: macos_reference_test
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  mediapipe_vision:
    path: {PACKAGE}
dependency_overrides:
  mediapipe_core:
    path: {PACKAGE.parent / 'mediapipe-core'}
dev_dependencies:
  crypto: ^3.0.6
  test: ^1.31.0
hooks:
  user_defines:
{core_hook_defines()}    mediapipe_vision:
      tasks: [face_detector, face_landmarker, gesture_recognizer, hand_landmarker,
              holistic_landmarker, image_classifier, image_embedder,
              image_segmenter, object_detector,
              pose_landmarker]
''')
    return root


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python', type=Path,
                        help="Python with this host's pinned official wheel")
    parser.add_argument('--output-dir', type=Path,
                        default=PACKAGE / 'build/macos-reference-validation')
    args = parser.parse_args()
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise SystemExit('macOS reference validation requires macOS arm64.')
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    python = args.python.absolute() if args.python else install(
        output / 'python-install', 'macos/arm64')
    env = {**os.environ, 'MPLCONFIGDIR': str(output / 'matplotlib')}

    cpu = output / 'cpu'
    oracle = generate(
        output / 'cpu-generation', cpu, 'macos/arm64',
        FACE_TASKS + [('landmark_tasks', 'landmark_tasks'),
                      ('image_tasks', 'image_tasks'),
                      ('object_detector', 'object_detection'),
                      ('segmenter_tasks', 'segmenter_tasks')],
        FACE_FILES + ['landmark_tasks/official_reference.json',
                      'image_tasks/official_reference.json',
                      'object_detection/official_reference.json',
                      'object_detection/official_video_reference.json',
                      'segmenter_tasks/official_reference.json'],
        python=python, env=env)
    print(json.dumps(oracle['comparisons'], indent=2), flush=True)

    root = test_root(output / 'consumer')
    env.update(MEDIAPIPE_CPU_REFERENCE_DIR=str(cpu),
               MEDIAPIPE_SAME_HOST_CPU_REFERENCES='1',
               MEDIAPIPE_LANDMARK_TASKS='hand,pose,gesture,holistic')
    run(['dart', 'pub', 'get'], root, output / 'dart-pub-get.log', env=env)
    # A task's close waits for Google's usage-logging upload, so a slow reply
    # holds a test past the default 30 s (upstream-issues.md UP-025); the
    # upload request itself gives up after 60 s.
    run(['dart', 'test', 'test/face_landmarker_test.dart',
         'test/landmark_tasks_test.dart', 'test/image_tasks_test.dart',
         'test/object_detector_test.dart', 'test/segmenter_tasks_test.dart',
         '--timeout', '180s', '--reporter', 'expanded'], root,
        output / 'dart-tests.log', env=env)
    print('Official macOS runtime comparisons passed for Face, Hand, Pose, '
          'Gesture, Holistic, Object Detector, Image Classifier, Image '
          'Embedder and Image Segmenter on the CPU.', flush=True)


if __name__ == '__main__':
    main()

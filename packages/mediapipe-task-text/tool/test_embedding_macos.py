"""Fresh macOS Flutter debug/release consumer with verified downloads.

Copies only publishable Dart packages: no native builds or model cache. Fetches
the pinned models and Google's text and vision libraries (the libraries from
MEDIAPIPE_ASSET_SOURCE when it is set), then compares
official outputs while face tasks, MagicTouch and all six text tasks coexist.
Bazel/CMake/Python are blocked in builds. Xcode's Clang compiles only the small
callback-copy adapter.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from prepare_classic_text_reference import digest, reference_file
from consumer_packages import configure_macos, consumer_environment, copy_package, core_hook_defines

PACKAGE = Path(__file__).resolve().parents[1]
REPO = PACKAGE.parents[1]


def main():
    build = REPO / 'build/ci-tmp'
    build.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix='embedding-consumer-', dir=build))
    packages = root / 'packages'
    for name in ('mediapipe-core', 'mediapipe-task-text', 'mediapipe-task-vision'):
        copy_package(REPO / 'packages' / name, packages / name)
    guards = root / 'blocked-tools'
    guards.mkdir()
    blocked_log = root / 'blocked-tools.log'
    for name in ('bazel', 'bazelisk', 'cmake', 'ninja', 'python', 'python3'):
        path = guards / name
        path.write_text('#!/bin/sh\necho "Unexpected build tool: $0" >> "$MEDIAPIPE_BLOCKED_TOOLS_LOG"\nexit 97\n')
        path.chmod(0o755)
    env = consumer_environment(PATH=str(guards) + os.pathsep + os.environ['PATH'],
                               MEDIAPIPE_BLOCKED_TOOLS_LOG=str(blocked_log))
    app = root / 'app'
    subprocess.run(['flutter', 'create', '--platforms=macos', '--empty', '--no-pub',
                    '--project-name', 'embedding_consumer', str(app)], env=env, check=True)
    (app / 'pubspec.yaml').write_text('''name: embedding_consumer
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  mediapipe_core:
    path: ../packages/mediapipe-core
  mediapipe_text:
    path: ../packages/mediapipe-task-text
  mediapipe_vision:
    path: ../packages/mediapipe-task-vision
dependency_overrides:
  mediapipe_core:
    path: ../packages/mediapipe-core
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
flutter:
  assets:
    - assets/
hooks:
  user_defines:
''' + core_hook_defines() + '''    mediapipe_vision:
      tasks: [face_detector, face_landmarker, interactive_segmenter]
''')
    assets = app / 'assets'
    assets.mkdir()
    shutil.copyfile(PACKAGE / 'test/fixtures/embedding_gemma/official_reference.json', assets / 'embedding_reference.json')
    shutil.copyfile(PACKAGE / 'test/fixtures/proofreader/official_reference.json', assets / 'proofreader_reference.json')
    shutil.copyfile(PACKAGE / 'test/fixtures/summarizer/official_reference.json', assets / 'summarizer_reference.json')
    classic_reference = reference_file()
    shutil.copyfile(classic_reference, assets / 'classic_text_reference.json')
    vision = REPO / 'packages/mediapipe-task-vision'
    for name in ('animals-299x150.rgb', 'raw-dog.f32.gz'):
        shutil.copyfile(vision / 'test/fixtures/interactive_segmentation' / name, assets / name)
    shutil.copyfile(vision / 'test/fixtures/face_detection/landmark-ex1.jpg', assets / 'landmark-ex1.jpg')
    shutil.copyfile(PACKAGE / 'tool/flutter_embedding_validation.dart.template', app / 'lib/validation.dart')
    shutil.copyfile(PACKAGE / 'tool/flutter_summarizer_validation.dart.template', app / 'lib/summarizer_validation.dart')
    shutil.copyfile(PACKAGE / 'test/support/classic_text_validation.dart', app / 'lib/classic_text_validation.dart')
    (app / 'bin').mkdir()
    (app / 'bin/download_models.dart').write_text('''import 'dart:io';
import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
Future<void> main() async {
  await downloadVerified(TextModels.bertClassifier, File('assets/bert_classifier.tflite'));
  await downloadVerified(TextModels.universalSentenceEncoder, File('assets/universal_sentence_encoder.tflite'));
  await downloadVerified(TextModels.languageDetector, File('assets/language_detector.tflite'));
  await downloadVerified(TextModels.embeddingGemma, File('assets/embedding_gemma.task'));
  await downloadVerified(TextModels.proofreader, File('assets/proofread_quant_200m.litertlm'));
  await downloadVerified(TextModels.summarizer, File('assets/summarization_quant_200m_2modes.litertlm'));
  await downloadVerified(VisionModels.interactiveSegmenter, File('assets/interactive_segmentation.task'));
  await downloadVerified(VisionModels.faceDetector, File('assets/blaze_face_short_range.tflite'));
  await downloadVerified(VisionModels.faceLandmarker, File('assets/face_landmarker.task'));
}
''')
    (app / 'lib/main.dart').write_text('''import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'validation.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    stdout.writeln('EMBEDDING_REPORT ' + jsonEncode(await validateEmbedding()));
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\\n$stack');
    exit(1);
  }
}
''')
    (app / 'integration_test').mkdir()
    (app / 'integration_test/embedding_test.dart').write_text('''import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/validation.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('official modern text and vision coexist on macOS CPU', (tester) async {
    final report = await validateEmbedding();
    expect(report['reference_cases'], 17);
    expect((report['proofreader'] as Map)['reference_cases'], 9);
    expect((report['summarizer'] as Map)['reference_cases'], 10);
    expect((report['classic_text'] as Map)['reference_cases'], 26);
    expect(report['coexisting_tasks'], 9);
    print('EMBEDDING_DEBUG_REPORT ' + jsonEncode(report));
  });
}
''')
    configure_macos(app, deployment_target='14.0')

    def run(command, log_name):
        print('Running: ' + ' '.join(command), flush=True)
        with (root / log_name).open('w') as log:
            process = subprocess.Popen(command, cwd=app, env=env, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True)
            for line in process.stdout:
                print(line, end='', flush=True)
                log.write(line)
            if process.wait():
                raise RuntimeError(f'{command} failed; see {root / log_name}')

    print('Fresh consumer: ' + str(root), flush=True)
    run(['flutter', 'pub', 'get'], 'pub-get.log')
    run(['dart', 'run', 'bin/download_models.dart'], 'downloads.log')
    run(['flutter', 'test', '-d', 'macos', 'integration_test/embedding_test.dart', '--reporter', 'expanded'], 'debug.log')
    run(['flutter', 'build', 'macos', '--release'], 'release-build.log')
    bundle = app / 'build/macos/Build/Products/Release/embedding_consumer.app'
    result = subprocess.run([str(bundle / 'Contents/MacOS/embedding_consumer')], cwd=app,
                            env=env, capture_output=True, text=True, timeout=120)
    (root / 'release.log').write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f'Release inference failed: {result.stderr}')
    reports = [line.removeprefix('EMBEDDING_REPORT ') for line in result.stdout.splitlines()
               if line.startswith('EMBEDDING_REPORT ')]
    if len(reports) != 1:
        raise RuntimeError('Release app did not return a validation report.')
    report = json.loads(reports[0])
    frameworks = [path.name for path in (bundle / 'Contents/Frameworks').iterdir()]
    # One library per family; the hooks verify each against its pin.
    for family in ('mediapipe_tasks_text', 'mediapipe_tasks_vision'):
        if frameworks.count(family + '.framework') != 1:
            raise RuntimeError(f'{family} must be bundled exactly once: {frameworks}')
    if sum('mediapipe_text_stream' in name for name in frameworks) != 1:
        raise RuntimeError(f'Callback adapter must be bundled exactly once: {frameworks}')
    if blocked_log.exists() or any(packages.rglob('build/native')):
        raise RuntimeError('Native build tools were accessed by the fresh consumer.')
    report.update({'debug_inference': 'passed', 'release_inference': 'passed',
                   'classic_text_reference_sha256': digest(classic_reference),
                   'classic_text_reference_source': 'same-host official wheel' if os.environ.get(
                       'MEDIAPIPE_CLASSIC_TEXT_REFERENCE_DIR') else 'checked-in official wheel',
                   'source': 'asset_source' if os.environ.get('MEDIAPIPE_ASSET_SOURCE')
                   else 'download', 'mediapipe_source_build': False,
                   'blocked_build_tools': ['bazel', 'bazelisk', 'cmake', 'ninja', 'python', 'python3'],
                   'callback_adapter': 'compiled with system Clang',
                   'frameworks': frameworks})
    (root / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)
    print('Fresh macOS consumer passed: ' + str(root / 'report.json'), flush=True)


if __name__ == '__main__':
    main()

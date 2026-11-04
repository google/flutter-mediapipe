"""Test the text and audio packages against Google's library on this host.

Installs Google's pinned official wheel for this host once, generates the text
and audio references with it, downloads the pinned models, and runs both
packages' Dart suites against those same-host references, after the audio
stream bridge's AddressSanitizer test outside Windows. CI runs it on the
Linux x64 and Windows x64 desktop runners; it runs on macOS arm64 as well.
Python only prepares the expected outputs; the suites load Google's library
through the packages, as an app does.
"""
import json
import os
from pathlib import Path
import platform
import sys

REPO = Path(__file__).resolve().parents[1]
TEXT = REPO / 'packages/mediapipe-task-text'
AUDIO = REPO / 'packages/mediapipe-task-audio'
sys.path.insert(0, str(REPO / 'packages/mediapipe-core/tool'))
from official_wheels import host_runtime, pinned_venv  # noqa: E402
from tool_helpers import run  # noqa: E402


def main():
    # Test names and Google's logs are UTF-8; Windows CI defaults to cp1252.
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    runtime = host_runtime()
    evidence = REPO / 'build/ci-tmp/text-audio'
    evidence.mkdir(parents=True, exist_ok=True)
    environment = REPO / f'build/ci-tmp/official-python-{runtime["version"]}'
    python = pinned_venv(environment, runtime, log=evidence / 'pip.log')

    for package in (TEXT, AUDIO):
        run(['dart', 'pub', 'get'], package, evidence / f'{package.name}-pub.log')
    run(['dart', 'tool/download_models.dart'], TEXT, evidence / 'text-models.log')
    run(['dart', 'tool/download_models.dart'], AUDIO, evidence / 'audio-model.log')
    text_reference = REPO / 'build/classic-text-reference'
    audio_reference = REPO / 'build/audio-reference'
    run([sys.executable, '-B', TEXT / 'tool/prepare_classic_text_reference.py',
         '--python', python, '--output-dir', text_reference], REPO,
        evidence / 'text-reference.log')
    run([sys.executable, '-B', AUDIO / 'tool/prepare_audio_reference.py',
         '--python', python, '--output-dir', audio_reference], REPO,
        evidence / 'audio-reference.log')

    if platform.system() != 'Windows':
        # The audio stream's callback-copy bridge, under AddressSanitizer, as
        # make test_audio_stream_bridge runs it on macOS; MSVC compiles it on
        # Windows inside the package's build hook, which the suite below
        # exercises.
        binary = evidence / 'audio_stream_bridge_test'
        run(['clang', '-Wall', '-Wextra', '-Werror', '-g', '-fsanitize=address', '-pthread',
             AUDIO / 'native/audio_stream_bridge.c', AUDIO / 'native/audio_stream_bridge_test.c',
             '-o', binary], REPO, evidence / 'audio-bridge-build.log')
        run([binary], REPO, evidence / 'audio-bridge-test.log')

    env = {**os.environ,
           'MEDIAPIPE_CLASSIC_TEXT_REFERENCE_DIR': str(text_reference),
           'MEDIAPIPE_AUDIO_REFERENCE_DIR': str(audio_reference)}
    # The text package's generative tasks run in tool/test_modern_text.py. A
    # task's close waits for Google's usage-logging upload, so a slow reply
    # holds a test past the default 30 s (upstream-issues.md UP-025).
    for package, name, extra in ((TEXT, 'text', ['--exclude-tags', 'modern-text']),
                                 (AUDIO, 'audio', [])):
        run(['dart', 'test', *extra, '--timeout', '180s', '--reporter', 'expanded'],
            package, evidence / f'{name}-tests.log', env)
    receipts = {name: json.loads((folder / 'provenance.json').read_text(encoding='utf-8'))
                for name, folder in [('text', text_reference), ('audio', audio_reference)]}
    (evidence / 'report.json').write_text(json.dumps({
        'runtime': 'mediapipe==' + runtime['version'],
        'library_sha256': runtime['library_sha256'],
        'os': platform.platform(),
        'tasks': ['audio_classifier', 'language_detector', 'text_classifier', 'text_embedder'],
        'checked_in_reference_differences': {
            name: receipt['checked_in_reference_differences']
            for name, receipt in receipts.items()},
    }, indent=2) + '\n', encoding='utf-8')
    print(f'Text and audio passed against Google\'s {runtime["version"]} library: {evidence}',
          flush=True)


if __name__ == '__main__':
    main()

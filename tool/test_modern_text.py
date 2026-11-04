"""Test EmbeddingGemma, Proofreader and Summarizer against Google's library here.

Installs Google's pinned official wheel for this host once (the same environment
tool/test_text_audio.py uses), downloads the three pinned models, generates the
three references with that wheel, and runs the text package's `modern-text`
tests against them: Google's completed and streamed outputs for the same model,
runtime and inputs, each option, stream lifecycle, errors and disposal. CI runs
it on the Linux x64 and Windows x64 desktop runners; it runs on macOS arm64 as
well. Python only prepares the expected outputs; the suite loads Google's
library through the package, as an app does.
"""
import json
import os
from pathlib import Path
import platform
import sys

REPO = Path(__file__).resolve().parents[1]
TEXT = REPO / 'packages/mediapipe-task-text'
sys.path.insert(0, str(REPO / 'packages/mediapipe-core/tool'))
from official_wheels import host_runtime, pinned_venv  # noqa: E402
from tool_helpers import run  # noqa: E402

TASKS = ['embedding_gemma', 'text_proofreader', 'text_summarizer']


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    runtime = host_runtime()
    evidence = REPO / 'build/ci-tmp/modern-text'
    evidence.mkdir(parents=True, exist_ok=True)
    environment = REPO / f'build/ci-tmp/official-python-{runtime["version"]}'
    python = pinned_venv(environment, runtime, log=evidence / 'pip.log')

    run(['dart', 'pub', 'get'], TEXT, evidence / 'text-pub.log')
    run(['dart', 'tool/download_models.dart', 'embedding_gemma', 'proofreader', 'summarizer'],
        TEXT, evidence / 'text-models.log')
    reference = REPO / 'build/modern-text-reference'
    run([sys.executable, '-B', TEXT / 'tool/prepare_modern_text_reference.py',
         '--python', python, '--output-dir', reference], REPO, evidence / 'reference.log')

    if platform.system() != 'Windows':
        # The callback-copy bridge, under AddressSanitizer, as make
        # test_text_stream_bridge runs it on macOS; MSVC compiles it on Windows
        # inside the package's build hook, which the suite below exercises.
        binary = evidence / 'text_stream_bridge_test'
        run(['clang', '-Wall', '-Wextra', '-Werror', '-g', '-fsanitize=address', '-pthread',
             TEXT / 'native/text_stream_bridge.c', TEXT / 'native/text_stream_bridge_test.c',
             '-o', binary], REPO, evidence / 'bridge-build.log')
        run([binary], REPO, evidence / 'bridge-test.log')

    env = {**os.environ, 'MEDIAPIPE_MODERN_TEXT_REFERENCE_DIR': str(reference)}
    # A task's close waits for Google's usage-logging upload, so a slow reply
    # holds a test past the default 30 s (upstream-issues.md UP-025).
    run(['dart', 'test', '--tags', 'modern-text', '--timeout', '180s',
         '--reporter', 'expanded'], TEXT,
        evidence / 'modern-text-tests.log', env)
    receipt = json.loads((reference / 'provenance.json').read_text(encoding='utf-8'))
    (evidence / 'report.json').write_text(json.dumps({
        'runtime': 'mediapipe==' + runtime['version'],
        'library_sha256': runtime['library_sha256'],
        'os': platform.platform(),
        'tasks': TASKS,
        'references': receipt['references'],
    }, indent=2) + '\n', encoding='utf-8')
    print(f'Modern text tasks passed against Google\'s {runtime["version"]} library: {evidence}',
          flush=True)


if __name__ == '__main__':
    main()

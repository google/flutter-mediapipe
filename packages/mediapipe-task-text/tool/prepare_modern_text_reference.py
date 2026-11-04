"""Generate same-host references for EmbeddingGemma, Proofreader and Summarizer.

Runs the three generators with Google's checksum-pinned wheel for this host and
writes `embedding_gemma.json`, `proofreader.json`, `summarizer.json` and a
`provenance.json` receipt into --output-dir. The package's `modern-text` tests
read that directory through MEDIAPIPE_MODERN_TEXT_REFERENCE_DIR and otherwise
use the checked-in macOS arm64 fixtures. The checked-in fixtures are never
rewritten.

The generated text must match Google's byte for byte on the same runtime, so
each host compares with the wheel of the release its libraries were built
from. A host of the same architecture generates the answers for a mobile
runtime too: the gallery's preparers bundle the result for the simulator and
emulator suites.
"""
import argparse
import json
from pathlib import Path
import platform
import subprocess
import sys

PACKAGE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PACKAGE.parent / 'mediapipe-core/tool'))
from official_wheels import host_runtime, pinned_venv  # noqa: E402
from tool_helpers import digest  # noqa: E402

GENERATORS = {
    'embedding_gemma': 'generate_embedding_gemma_reference.py',
    'proofreader': 'generate_proofreader_reference.py',
    'summarizer': 'generate_summarizer_reference.py',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    interpreter = parser.add_mutually_exclusive_group(required=True)
    interpreter.add_argument('--python', type=Path,
                             help="an interpreter with Google's pinned wheel installed")
    interpreter.add_argument('--venv', type=Path,
                             help='a virtual environment to create (or reuse) and install '
                                  "Google's pinned wheel into")
    parser.add_argument('--output-dir', required=True, type=Path)
    args = parser.parse_args()
    runtime = host_runtime()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    python = args.python
    if args.venv:
        python = pinned_venv(args.venv, runtime, log=args.output_dir / 'pip.log')
    references = {}
    for task, generator in GENERATORS.items():
        output = args.output_dir / f'{task}.json'
        log = args.output_dir / f'{task}.log'
        with log.open('w', encoding='utf-8') as handle:
            subprocess.run([str(python), '-B', str(PACKAGE / 'tool' / generator),
                            '--output', str(output)],
                           check=True, stdout=handle, stderr=subprocess.STDOUT)
        report = json.loads(output.read_text(encoding='utf-8'))
        assert report['runtime'] == 'mediapipe==' + runtime['version'], report['runtime']
        assert report['library_sha256'] == runtime['library_sha256']
        references[task] = {'file': output.name, 'sha256': digest(output),
                            'cases': len(report['cases'])}
        print(f'{task}: {len(report["cases"])} cases from Google\'s {runtime["version"]} wheel',
              flush=True)
    (args.output_dir / 'provenance.json').write_text(json.dumps({
        'source': 'official-python-api',
        'runtime': 'mediapipe==' + runtime['version'],
        'delegate': 'CPU',
        'library_sha256': runtime['library_sha256'],
        'wheel_sha256': runtime['wheel_sha256'],
        'os': platform.platform(),
        'machine': platform.machine(),
        'references': references,
    }, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

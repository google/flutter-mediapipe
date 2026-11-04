"""Build an AOT native-assets consumer and retain bounded validation/benchmark logs."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import tempfile

PACKAGE = Path(__file__).resolve().parent
ROOT = PACKAGE.parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--iterations', type=int, default=100)
    parser.add_argument('--reloads', type=int, default=10)
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('--validate-only', action='store_true')
    args = parser.parse_args()
    assert platform.system() == 'Darwin' and platform.machine() == 'arm64'
    assert args.iterations > 0 and args.reloads > 0 and args.timeout > 0
    build = ROOT / 'build/task-benchmarks'
    build.mkdir(parents=True, exist_ok=True)
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='run-', dir=build))
    output.mkdir(parents=True, exist_ok=True)

    def run(command, name, timeout):
        print('Running', ' '.join(command), flush=True)
        with (output / name).open('w') as log:
            subprocess.run(command, cwd=PACKAGE, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=timeout)

    run(['dart', 'pub', 'get'], 'pub-get.log', 120)
    run(['dart', 'build', 'cli', '--target', 'bin/main.dart'], 'build.log', 180)
    executable = PACKAGE / 'build/cli/macos_arm64/bundle/bin/main'
    metadata = {'chip': subprocess.check_output(['/usr/sbin/sysctl', '-n', 'machdep.cpu.brand_string'], text=True).strip(),
                'memory_bytes': int(subprocess.check_output(['/usr/sbin/sysctl', '-n', 'hw.memsize'], text=True)),
                'git_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
                'source_sha256': hashlib.sha256((PACKAGE / 'bin/main.dart').read_bytes()).hexdigest(),
                'executable_sha256': hashlib.sha256(executable.read_bytes()).hexdigest()}
    (output / 'provenance.json').write_text(json.dumps(metadata, indent=2) + '\n')
    run([str(executable), '--repo', str(ROOT), '--output', str(output / 'report.json'),
         '--iterations', str(args.iterations), '--reloads', str(args.reloads)] +
        (['--validate-only'] if args.validate_only else []), 'run.log', args.timeout)
    report = json.loads((output / 'report.json').read_text())
    assert report['status'] == 'passed', report.get('error')
    print(output, flush=True)
    for task, values in report.get('benchmarks', {}).items():
        print(task, 'median_ms', round(values['completed']['median_ms'], 3),
              'p95_ms', round(values['completed']['p95_ms'], 3), flush=True)
    print('option_cases', len(report['option_matrix']), 'rss_change_bytes', report.get('rss_change_bytes'), flush=True)


if __name__ == '__main__':
    main()

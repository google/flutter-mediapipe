"""Record which task/platform/delegate cells a CI step's suites covered.

Called after a test step, with that step's outcome, so a cell only counts as
passing when the suites that exercise it passed:

    python3 -B tool/coverage/record.py --suite android-sdk --platform android \
        --delegate cpu --tasks face_landmarker,hand_landmarker --outcome success

Rows land in build/coverage/<suite>.json; the job uploads that directory as a
`coverage-*` artifact and tool/coverage/gate.py reads every such artifact.
"""
import argparse
import json
import os
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MATRIX = json.loads((REPO / 'tool/coverage/matrix.json').read_text())['cells']


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--suite', required=True, help='unique name for this step')
    parser.add_argument('--platform', required=True)
    parser.add_argument('--delegate', required=True, choices=['cpu', 'gpu'])
    parser.add_argument('--tasks', required=True, help='comma-separated task names')
    parser.add_argument('--outcome', required=True,
                        help="the step's outcome: success, failure, cancelled or skipped")
    parser.add_argument('--tier', default='pr', choices=['pr', 'device'])
    parser.add_argument('--output-dir', type=Path, default=REPO / 'build/coverage')
    args = parser.parse_args()
    tasks = [t for t in args.tasks.split(',') if t]
    for task in tasks:
        cell = MATRIX.get(task, {}).get(args.platform, {}).get(args.delegate)
        if cell is None:
            raise SystemExit(f'{task}/{args.platform}/{args.delegate} is not in matrix.json')
        if cell.startswith('unsupported'):
            raise SystemExit(f'{task}/{args.platform}/{args.delegate} is {cell}; fix matrix.json')
    rows = [dict(task=task, platform=args.platform, delegate=args.delegate, suite=args.suite,
                 tier=args.tier, passed=args.outcome == 'success', outcome=args.outcome,
                 sha=os.environ.get('GITHUB_SHA'), run=os.environ.get('GITHUB_RUN_ID'),
                 job=os.environ.get('GITHUB_JOB'))
            for task in tasks]
    args.output_dir.mkdir(parents=True, exist_ok=True)
    path = args.output_dir / f'{args.suite}.json'
    if path.exists():
        rows = json.loads(path.read_text()) + rows
    path.write_text(json.dumps(rows, indent=2) + '\n')
    print(f'{args.suite}: {len(tasks)} {args.platform}/{args.delegate} cells, {args.outcome}')


if __name__ == '__main__':
    main()

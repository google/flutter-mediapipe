"""Fail unless every required cell in matrix.json has a passing CI row.

In CI (.github/workflows/coverage-gate.yaml) it first waits for this commit's
other workflow runs, then downloads their `coverage-*` artifacts:

    python3 -B tool/coverage/gate.py --collect --sha <sha> --rows build/coverage-rows

Locally, point it at a directory of rows (build/coverage from record.py):

    python3 -B tool/coverage/gate.py --rows build/coverage

It prints the task x platform table (also to $GITHUB_STEP_SUMMARY) and exits
non-zero when a required cell has no passing row.
"""
import argparse
import calendar
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[2]
PLATFORMS = ['web', 'android', 'ios', 'macos', 'linux', 'windows']
# Workflows whose jobs record rows. The gate waits for each to finish on the
# commit; a missing one is a failure rather than silently fewer rows.
RECORDING_WORKFLOWS = ['.github/workflows/android.yaml', '.github/workflows/ios.yaml',
                       '.github/workflows/web.yaml', '.github/workflows/desktop.yaml',
                       '.github/workflows/main.yaml', '.github/workflows/retrieval.yaml',
                       '.github/workflows/decision.yaml']
# Physical-device workflows, dispatched by hand for a branch or main. Their
# rows carry tier 'device'; the gate does not wait for them.
DEVICE_WORKFLOWS = ['.github/workflows/android-face-testlab.yml']
# How old a run on main may be when this commit has no device run.
DEVICE_WINDOW_HOURS = 48
NO_ROW = 'no row recorded'
# gh failures a later attempt can survive: GitHub's 5xx and rate limits, the
# network, and an artifact cut off in transit.
TRANSIENT_GH = re.compile(r'HTTP (429|5\d\d)|rate limit|connect|timeout|timed out|deadline exceeded'
                          r'|\blookup\b|\bEOF\b|stream error|not a valid zip', re.IGNORECASE)
GH_RETRY_SECONDS = (15, 30, 60)


def load_matrix():
    return json.loads((REPO / 'tool/coverage/matrix.json').read_text())['cells']


def load_rows(directory):
    rows = []
    for path in sorted(Path(directory).rglob('*.json')):
        rows.extend(json.loads(path.read_text()))
    return rows


def evaluate(matrix, rows, strict_devices=True):
    """Returns (table cells keyed by (task, platform, delegate), failures, ahead, awaiting).

    A 'device' cell needs a passing row with tier 'device'. Without
    [strict_devices] (pull requests, which cannot run hardware on every push),
    a device cell with no row at all is only reported as awaiting.
    """
    passed = {(r['task'], r['platform'], r['delegate']) for r in rows if r['passed']}
    on_device = {(r['task'], r['platform'], r['delegate']) for r in rows
                 if r['passed'] and r.get('tier') == 'device'}
    # A step that never reached a verdict says so rather than "failed".
    failed = {(r['task'], r['platform'], r['delegate']):
              f"{'failed' if r.get('outcome', 'failure') == 'failure' else r['outcome']} in {r['suite']}"
              for r in rows if not r['passed']}
    states, failures, ahead, awaiting = {}, [], [], []
    for task, platforms in matrix.items():
        for platform, delegates in platforms.items():
            for delegate, status in delegates.items():
                key = (task, platform, delegate)
                if status == 'required':
                    if key in passed:
                        states[key] = 'pass'
                    else:
                        states[key] = 'fail'
                        reason = failed.get(key, NO_ROW)
                        failures.append(f'{task} / {platform} / {delegate}: {reason}')
                elif status == 'device':
                    if key in on_device:
                        states[key] = 'pass'
                    elif key in failed or strict_devices:
                        states[key] = 'fail'
                        reason = failed.get(key, f'no device run for this commit or on main '
                                                 f'within {DEVICE_WINDOW_HOURS} h')
                        failures.append(f'{task} / {platform} / {delegate}: {reason}')
                    else:
                        states[key] = 'awaiting'
                        awaiting.append(f'{task} / {platform} / {delegate}')
                elif status.startswith('pending'):
                    states[key] = 'ahead' if key in passed else 'pending'
                    if key in passed:
                        ahead.append(f'{task} / {platform} / {delegate} passes but is '
                                     f'"{status}"; mark it required')
                else:
                    states[key] = 'unsupported'
    return states, failures, ahead, awaiting


SYMBOL = {'pass': '✅', 'fail': '❌', 'pending': '⏳', 'ahead': '✳️', 'unsupported': '·',
          'awaiting': '📱'}


def table(matrix, states):
    lines = ['| Task | ' + ' | '.join(PLATFORMS) + ' |',
             '|---|' + '---|' * len(PLATFORMS)]
    for task in matrix:
        cells = []
        for platform in PLATFORMS:
            cells.append(' '.join(f'{d.upper()} {SYMBOL[states[(task, platform, d)]]}'
                                  for d in ('cpu', 'gpu')))
        lines.append(f'| {task} | ' + ' | '.join(cells) + ' |')
    lines.append('')
    lines.append('✅ passed · ❌ required, no pass · 📱 awaiting a physical-device run · '
                 '⏳ planned · ✳️ planned and already passing · `·` unsupported upstream '
                 '(reason in tool/coverage/matrix.json)')
    return '\n'.join(lines)


def gh(*args, scratch=None):
    """Runs gh and prints its stderr when it fails. Only a failure TRANSIENT_GH
    names is tried again, with a warning; [scratch] is cleared first, since gh run
    download refuses to overwrite what an earlier attempt left there."""
    for delay in (*GH_RETRY_SECONDS, None):
        result = subprocess.run(['gh', *args], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout
        print(f'gh {" ".join(args)}: {result.stderr.strip()}', file=sys.stderr, flush=True)
        if delay is None or not TRANSIENT_GH.search(result.stderr):
            raise subprocess.CalledProcessError(result.returncode, ['gh', *args],
                                                result.stdout, result.stderr)
        print(f'::warning::gh {args[0]} {args[1]} failed, retrying in {delay} s: '
              f'{result.stderr.strip().splitlines()[-1]}', flush=True)
        if scratch:
            shutil.rmtree(scratch, ignore_errors=True)
        time.sleep(delay)


def collect(sha, output, timeout_minutes, poll_seconds=60):
    """Waits for this commit's recording workflow runs, downloads their rows, and
    returns the runs it read, by workflow path."""
    repository = os.environ['GITHUB_REPOSITORY']
    deadline = time.time() + timeout_minutes * 60
    while True:
        runs = json.loads(gh('api', f'repos/{repository}/actions/runs?head_sha={sha}&per_page=100'))
        latest = {}
        for run in runs['workflow_runs']:
            if run['path'] in RECORDING_WORKFLOWS and run['event'] in ('pull_request', 'push'):
                if run['path'] not in latest or run['id'] > latest[run['path']]['id']:
                    latest[run['path']] = run
        waiting = [p for p in RECORDING_WORKFLOWS
                   if p not in latest or latest[p]['status'] != 'completed']
        if not waiting:
            break
        if time.time() > deadline:
            raise SystemExit('Timed out waiting for: ' + ', '.join(waiting))
        print('Waiting for ' + ', '.join(Path(p).name for p in waiting), flush=True)
        time.sleep(poll_seconds)
    latest.update(device_runs(repository, runs['workflow_runs']))
    output.mkdir(parents=True, exist_ok=True)
    for path, run in sorted(latest.items()):
        print(f'{Path(path).name}: run {run["id"]} {run["conclusion"]}', flush=True)
        artifacts = json.loads(gh('api', f'repos/{repository}/actions/runs/{run["id"]}/artifacts?per_page=100'))
        if any(a['name'].startswith('coverage-') for a in artifacts['artifacts']):
            gh('run', 'download', str(run['id']), '--repo', repository,
               '--pattern', 'coverage-*', '--dir', str(output / str(run['id'])),
               scratch=output / str(run['id']))
    return latest


def device_runs(repository, commit_runs):
    """This commit's completed device runs, else each device workflow's newest
    completed run on main within the window."""
    found = {}
    for run in commit_runs:
        if run['path'] in DEVICE_WORKFLOWS and run['status'] == 'completed':
            if run['path'] not in found or run['id'] > found[run['path']]['id']:
                found[run['path']] = run
    cutoff = time.time() - DEVICE_WINDOW_HOURS * 3600
    for path in DEVICE_WORKFLOWS:
        if path in found:
            continue
        name = Path(path).name
        try:
            recent = json.loads(gh('api', f'repos/{repository}/actions/workflows/{name}/runs'
                                   '?branch=main&status=completed&per_page=5'))['workflow_runs']
        except subprocess.CalledProcessError as error:
            # GitHub knows a workflow only once the default branch holds its
            # file, so a repository whose main has none answers 404: no runs.
            if 'HTTP 404' not in error.stderr:
                raise
            recent = []
        for run in recent:
            started = calendar.timegm(time.strptime(run['created_at'], '%Y-%m-%dT%H:%M:%SZ'))
            if run['conclusion'] != 'cancelled' and started >= cutoff:
                found[path] = run
                break
    return found


def stop_reason(repository, job):
    """GitHub's own words: a job without steps looks the same whether no runner
    took it, its image is gone or someone cancelled the run."""
    try:
        annotations = json.loads(gh('api', f'repos/{repository}/check-runs/{job["id"]}/annotations'))
    except subprocess.CalledProcessError:
        annotations = []
    messages = [a['message'] for a in annotations if a['annotation_level'] == 'failure']
    return messages[0] if messages else 'GitHub gave no reason'


def stopped_jobs(repository, runs):
    """The cancelled or timed-out jobs of [runs], as report lines."""
    lines = []
    for path, run in sorted(runs.items()):
        jobs = json.loads(gh('api', f'repos/{repository}/actions/runs/{run["id"]}/jobs'
                             '?filter=latest&per_page=100'))['jobs']
        for job in jobs:
            if job['conclusion'] in ('cancelled', 'timed_out'):
                steps = '' if job['steps'] else ' with no step run'
                lines.append(f'- {Path(path).name} / {job["name"]}: {job["conclusion"]}{steps}: '
                             f'{stop_reason(repository, job)} ({job["html_url"]})')
    return lines


def missing_rows_report(runs, failures):
    """Says why cells have no row: a job that stops early records nothing. Only
    explains, and its own failure is reported rather than raised: the gate's
    verdict is already decided by [failures]."""
    if not runs or not any(f.endswith(NO_ROW) for f in failures):
        return []
    try:
        jobs = stopped_jobs(os.environ['GITHUB_REPOSITORY'], runs)
    except subprocess.CalledProcessError as error:
        jobs = [f'- Could not list the jobs: {error.stderr.strip()}']
    return (['### Jobs that may explain the cells with no row', ''] +
            (jobs or ['No job on the runs read was cancelled or timed out, so a job failed '
                      'before its record step or no suite records those cells.']) + [''])


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--rows', type=Path, default=REPO / 'build/coverage')
    parser.add_argument('--collect', action='store_true')
    parser.add_argument('--sha')
    parser.add_argument('--timeout-minutes', type=int, default=180)
    parser.add_argument('--lenient-devices', action='store_true',
                        help='report device cells without device evidence instead of failing')
    args = parser.parse_args()
    runs = collect(args.sha, args.rows, args.timeout_minutes) if args.collect else {}
    matrix = load_matrix()
    states, failures, ahead, awaiting = evaluate(matrix, load_rows(args.rows),
                                                 strict_devices=not args.lenient_devices)
    report = ['## Task coverage', '', table(matrix, states), '']
    if failures:
        report += ['### Required cells without a passing row', ''] + [f'- {f}' for f in failures] + ['']
        report += missing_rows_report(runs, failures)
    if awaiting:
        report += ['### Awaiting a physical-device run', '',
                   'Dispatch the device workflow (Android devices, Firebase Test Lab) for '
                   'this branch or main.', ''] + [f'- {a}' for a in awaiting] + ['']
    if ahead:
        report += ['### Ahead of plan', ''] + [f'- {a}' for a in ahead] + ['']
    text = '\n'.join(report)
    print(text)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as handle:
            handle.write(text + '\n')
    if failures:
        sys.exit(f'{len(failures)} required cells have no passing row')


if __name__ == '__main__':
    main()

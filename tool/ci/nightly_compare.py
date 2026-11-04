"""Compares the baseline and nightly halves of a nightly-compare.yaml run.

Each comparison job runs twice in the run, named `... (baseline) ...` on
main's pins and `... (nightly) ...` with tool/ci/nightly_pin.py's patch. This
pairs them by name, then reads, through the GitHub API:

- every step's conclusion, so a suite that fails on the nightly and passes on
  the baseline is a regression. A step that fails on both, a setup step
  (checkout, toolchains, apt, downloads) or a cancelled or missing job is
  infrastructure, and opens no issue;
- the measurement records in each job's log: `SDK_* {json}`,
  `MEDIAPIPE_REFERENCE_DELTAS <task> {json}` and `LIVE_STREAM_VIDEO_DELTA`.
  Records pair by marker, their identifying fields and occurrence. Timing
  fields are left out. A field with a test tolerance (TOLERANCES, REFERENCE)
  drifts when the nightly moves it by more than that tolerance; other changed
  values are listed only.

With pin_nightly.py's report it adds the C header API changes. It writes the
job summary table (summary.md, and $GITHUB_STEP_SUMMARY), findings.json, the
issue body (issue.md) and the step outputs: issue (a C API change, a
regression or drift: open the nightly's issue), escalate (a regression or
drift: run the full matrix), and title.

    python3 -B tool/ci/nightly_compare.py --pin build/nightly-pin \\
        --scope daily --out build/nightly-compare

NIGHTLY_COMPARE_TOLERANCE_SCALE multiplies every tolerance (default 1); a
negative scale makes every compared value drift, which tests the issue path.
"""
import argparse
from collections import Counter, namedtuple
import fnmatch
import json
import os
from pathlib import Path
import re
import subprocess
import time

REPO = Path(__file__).resolve().parents[2]
SIDES = ('baseline', 'nightly')
SIDE = re.compile(r' \((baseline|nightly)\)')

# A test's bound on a field, and where the test sets it: test_nightly_compare.py
# reads `pattern`'s number from `source` so the two cannot part. A `floor` is a
# lower bound on a value near 1 (an agreement or a cosine); its tolerance is
# 1 - limit.
Bound = namedtuple('Bound', 'limit source pattern floor', defaults=(False,))
SDK_TESTS = 'gallery/integration_test/'
VISION_TESTS = 'packages/mediapipe-task-vision/test/'
_LANDMARK_CROSS = Bound(0.03, SDK_TESTS + 'sdk_landmark_tasks_test.dart',
                        r'const _crossRuntime = ([\d.e-]+);')
TOLERANCES = {
    'SDK_LANDMARK_TASK': {'official_max_delta': _LANDMARK_CROSS,
                          'official_rotated_max_delta': _LANDMARK_CROSS},
    'SDK_HAND_LANDMARKER': {'official_max_delta': Bound(
        0.03, SDK_TESTS + 'sdk_hand_landmarker_test.dart', r'const _crossRuntime = ([\d.e-]+);')},
    'SDK_EMBEDDER': {'official_cosine': Bound(
        0.99, SDK_TESTS + 'sdk_embedder_test.dart', r'const _crossRuntime = ([\d.e-]+);', True)},
    'SDK_SEGMENTER': {
        'category_agreement': Bound(0.95, SDK_TESTS + 'sdk_segmenter_test.dart',
                                    r'const _categoryAgreement = ([\d.e-]+);', True),
        'share_error': Bound(0.01, SDK_TESTS + 'sdk_segmenter_test.dart',
                             r'const _shareError = ([\d.e-]+);'),
        'confidence_*.mean': Bound(0.02, SDK_TESTS + 'sdk_segmenter_test.dart',
                                   r'const _confidenceMean = ([\d.e-]+);'),
    },
    'SDK_INTERACTIVE': {
        'grid_error': Bound(0.02, SDK_TESTS + 'sdk_interactive_segmenter_test.dart',
                            r'expect\(gridError, lessThan\(([\d.e-]+)\)\);'),
        'mean_delta': Bound(0.01, SDK_TESTS + 'sdk_interactive_segmenter_test.dart',
                            r'expect\(meanDelta, lessThan\(([\d.e-]+)\)\);'),
        'foreground_delta': Bound(0.01, SDK_TESTS + 'sdk_interactive_segmenter_test.dart',
                                  r'expect\(foregroundDelta, lessThan\(([\d.e-]+)\)\);'),
    },
    'SDK_MODERN_TEXT': {
        'max_float_error': Bound(0.02, SDK_TESTS + 'sdk_modern_text_test.dart',
                                 r'const _embeddingBound = ([\d.e-]+);'),
        'max_quantized_error': Bound(2, SDK_TESTS + 'sdk_modern_text_test.dart',
                                     r'const _quantizedBound = ([\d.e-]+);'),
    },
    'LIVE_STREAM_VIDEO_DELTA': {'max': Bound(
        1e-5, VISION_TESTS + 'live_stream_runtime_test.dart',
        r'expect\(largest, lessThanOrEqualTo\(([\d.e-]+)\)\);')},
}
# MEDIAPIPE_REFERENCE_DELTAS: `{delegate: {group: {maximum_absolute_error}}}`
# per task, bounded as the desktop suites bound each value. Keys are
# (task, delegate, group); '*' matches any.
_LANDMARKS = VISION_TESTS + 'landmark_tasks_test.dart'
_SEGMENTER = VISION_TESTS + 'segmenter_tasks_test.dart'
_IMAGE = VISION_TESTS + 'image_tasks_test.dart'
_FACE = VISION_TESTS + 'face_landmarker_test.dart'
REFERENCE = {
    ('*', 'cpu', '*'): Bound(1e-5, _LANDMARKS, r"_gpuTolerances\[group\]! : ([\d.e-]+)\)"),
    ('*', 'gpu', '*'): Bound(0.002, _LANDMARKS, r"'landmarks': ([\d.e-]+),"),
    ('*', 'gpu', 'landmarks'): Bound(0.002, _LANDMARKS, r"'landmarks': ([\d.e-]+),"),
    ('*', 'gpu', 'world_landmarks'): Bound(0.002, _LANDMARKS, r"'world_landmarks': ([\d.e-]+),"),
    ('*', 'gpu', 'other'): Bound(0.04, _LANDMARKS, r"'other': ([\d.e-]+),"),
    ('image_segmenter', 'gpu', 'confidence_masks'): Bound(
        0.01, _SEGMENTER, r"'confidence_masks': ([\d.e-]+),"),
    ('image_segmenter', 'gpu', 'category_mask'): Bound(
        0.05, _SEGMENTER, r"'category_mask': ([\d.e-]+)\}"),
    ('image_classifier', 'gpu', '*'): Bound(0.001, _IMAGE, r'const _gpuScoreTolerance = ([\d.e-]+);'),
    ('image_embedder', 'gpu', '*'): Bound(0.001, _IMAGE, r'const _gpuEmbeddingTolerance = ([\d.e-]+);'),
    ('face_landmarker', 'cpu', 'face_landmarks'): Bound(
        1e-4, _FACE, r'final tolerance = gpu \? [\d.]+ : ([\d.e-]+);'),
    ('face_landmarker', 'gpu', 'face_landmarks'): Bound(
        0.002, _FACE, r'final tolerance = gpu \? ([\d.e-]+) :'),
    ('face_landmarker', 'cpu', 'face_blendshapes'): Bound(
        0.002, _FACE, r"gpu \? [\d.]+ : ([\d.e-]+),\s*'face_blendshapes'"),
    ('face_landmarker', 'gpu', 'face_blendshapes'): Bound(
        0.04, _FACE, r"gpu \? ([\d.e-]+) : [\d.]+,\s*'face_blendshapes'"),
    ('face_landmarker', 'cpu', 'facial_transformation_matrixes'): Bound(
        0.005, _FACE, r"gpu \? [\d.]+ : ([\d.e-]+),\s*'facial_transformation_matrixes'"),
    ('face_landmarker', 'gpu', 'facial_transformation_matrixes'): Bound(
        0.06, _FACE, r"gpu \? ([\d.e-]+) : [\d.]+,\s*'facial_transformation_matrixes'"),
    ('face_detector', '*', 'bounding_box'): Bound(
        1, VISION_TESTS + 'face_detector_test.dart', r"box\['origin_x'\] as num,\s*(\d+),"),
}

# Steps whose failure on one side says nothing about the build: the runner,
# checkout and toolchains, package mirrors and downloads that do not use the
# pins. (The nightly's own download is in the suites and gallery steps.)
INFRA_STEP = re.compile(
    r"^(Set up job|Complete job|Post |Run (actions|android-actions|subosito|reactivecircus)/"
    r"|Run \./\.github/actions/(setup|apt-install|android-ndk|record-coverage|nightly-pin)"
    r"|Install |Download |Enable |Google's references|Start the gallery server)")

MARK = re.compile(r'(?:^|[\s:])(SDK_[A-Z_]+|MEDIAPIPE_REFERENCE_DELTAS) (?:(\S+) )?(\{.*\})\s*$')
LIVE = re.compile(r'(?:^|[\s:])LIVE_STREAM_VIDEO_DELTA (\d+) values, max (\S+)')
STAMP = re.compile(r'^\ufeff?\d{4}-\d\d-\d\dT[\d:.]+Z ?')
ANSI = re.compile(r'\x1b\[[0-9;]*[A-Za-z]')
IDS = ('task', 'event', 'delegate', 'sample', 'mode', 'model', 'name', 'case', 'input')


def records(log):
    """`{key: value}` for the measurement records in a job log; a key is the
    marker, its tag and identifying fields, and the occurrence."""
    found, seen = {}, Counter()
    for line in log.splitlines():
        text = ANSI.sub('', STAMP.sub('', line)).rstrip()
        mark, live = MARK.search(text), LIVE.search(text)
        if mark:
            marker, tag, body = mark.groups()
            try:
                value = json.loads(body)
            except ValueError:
                continue
            if not isinstance(value, dict):
                continue
            key = (marker, tag or '') + tuple(f'{i}={value[i]}' for i in IDS if i in value)
        elif live:
            key = ('LIVE_STREAM_VIDEO_DELTA', '')
            value = {'values': int(live.group(1)), 'max': float(live.group(2))}
        else:
            continue
        seen[key] += 1
        found[key + (f'#{seen[key]}',)] = value
    return found


def flat(value, prefix=''):
    if isinstance(value, dict):
        for key, item in value.items():
            yield from flat(item, f'{prefix}.{key}' if prefix else str(key))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from flat(item, f'{prefix}[{index}]')
    else:
        yield prefix, value


def timed(field):
    """Wall-clock fields, which differ between runs of one build."""
    leaf = re.sub(r'\[\d+\]', '', field.rsplit('.', 1)[-1]).lower()
    return (leaf.endswith('ms') or leaf.endswith('fps') or leaf.endswith('frames')
            or leaf in ('seconds', 'duration', 'elapsed'))


def bound_for(key, field):
    """The Bound a test applies to `field` of the record `key`, or None."""
    marker, tag = key[0], key[1]
    if marker == 'MEDIAPIPE_REFERENCE_DELTAS':
        parts = field.split('.')
        if len(parts) != 3 or parts[2] != 'maximum_absolute_error':
            return None
        delegate, group = parts[0], parts[1]
        for candidate in ((tag, delegate, group), (tag, '*', group), (tag, delegate, '*'),
                          ('*', delegate, group), ('*', delegate, '*')):
            if candidate in REFERENCE:
                return REFERENCE[candidate]
        return None
    for pattern, bound in TOLERANCES.get(marker, {}).items():
        if fnmatch.fnmatchcase(field, pattern):
            return bound
    return None


def tolerance(bound, scale=1.0):
    return (1 - bound.limit if bound.floor else bound.limit) * scale


def compare_records(base, new, scale=1.0):
    """`(drift, changed, only_base, only_new, worst)`: fields the nightly moved
    beyond their tolerance; other changed values; records on one side only;
    and the largest move relative to its tolerance, as (ratio, text)."""
    drift, changed, worst = [], [], (0.0, '')
    for key in sorted(set(base) & set(new), key=str):
        a, b = dict(flat(base[key])), dict(flat(new[key]))
        for field in sorted(set(a) | set(b)):
            x, y = a.get(field), b.get(field)
            if timed(field) or field.endswith(('.path', '.official', '.measured')):
                continue
            numeric = all(isinstance(v, (int, float)) and not isinstance(v, bool)
                          for v in (x, y))
            bound = bound_for(key, field) if numeric else None
            if bound is not None:
                move, limit = abs(y - x), tolerance(bound, scale)
                if limit > 0 and move / limit > worst[0]:
                    worst = (move / limit, f'{field} {move:.3g} of {limit:.3g}')
                if move > limit:
                    drift.append((key, field, x, y, move, limit))
            elif x != y:
                changed.append((key, field, x, y))
    return (drift, changed, sorted(set(base) - set(new), key=str),
            sorted(set(new) - set(base), key=str), worst)


def judge(base, new):
    """Compares the two runs of one job: `(verdict, notes)`. Verdicts:
    'same', 'regression', 'fixed', 'infra'."""
    for side, job in (('baseline', base), ('nightly', new)):
        if job is None:
            return 'infra', [f'no {side} job']
        if job.get('conclusion') not in ('success', 'failure'):
            return 'infra', [f"{side} job {job.get('conclusion') or job.get('status')}"]
    a = {step['name']: step.get('conclusion') for step in base.get('steps', [])}
    b = {step['name']: step.get('conclusion') for step in new.get('steps', [])}
    regressions, infra, both, fixed = [], [], [], []
    for name in [step['name'] for step in new.get('steps', [])]:
        x, y = a.get(name), b.get(name)
        if x == 'failure' and y == 'failure':
            both.append(name)
        elif y == 'failure' and x == 'success':
            (infra if INFRA_STEP.match(name) else regressions).append(name)
        elif y == 'failure':
            infra.append(f'{name} (baseline {x or "absent"})')
        elif x == 'failure' and y == 'success':
            fixed.append(name)
    for name, x in a.items():
        if x == 'failure' and name not in b:
            infra.append(f'{name} (absent on the nightly)')
    notes = ([f'fails on the nightly only: {name}' for name in regressions]
             + [f'infrastructure: {name}' for name in infra]
             + [f'fails on both: {name}' for name in both]
             + [f'passes on the nightly only: {name}' for name in fixed])
    if regressions:
        return 'regression', notes
    if infra or both:
        return 'infra', notes
    if fixed:
        return 'fixed', notes
    return 'same', notes


def pair_jobs(jobs):
    """`{name without the side: {side: job}}` for the comparison jobs."""
    pairs = {}
    for job in jobs:
        match = SIDE.search(job['name'])
        if match:
            pairs.setdefault(SIDE.sub('', job['name'], count=1), {})[match.group(1)] = job
    return dict(sorted(pairs.items()))


ESCAPES = '--allow-escape-sequences'


def gh(*arguments):
    arguments = list(arguments)
    for attempt in range(4):
        result = subprocess.run(['gh', *arguments], capture_output=True, text=True,
                                encoding='utf-8', errors='replace')
        if result.returncode == 0:
            return result.stdout
        print(f'gh {" ".join(arguments)}: {result.stderr.strip()}', flush=True)
        # Newer gh refuses to print a job log with colours unless told to;
        # records() strips them. Older gh has no such flag, so only on request.
        if ESCAPES in result.stderr and ESCAPES not in arguments:
            arguments.insert(1, ESCAPES)
            continue
        time.sleep(15 * (attempt + 1))
    raise SystemExit(f'gh {" ".join(arguments)} failed')


def run_jobs(repository, run_id, attempt):
    lines = gh('api', '--paginate',
               f'repos/{repository}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100',
               '--jq', '.jobs[] | tojson')
    return [json.loads(line) for line in lines.splitlines() if line.strip()]


def header_diff(log):
    """The unified diff pin_nightly.py printed for the changed headers."""
    return [line[4:] for line in log.splitlines()
            if line.startswith('    ') and line[4:5] in ('-', '+', '@')]


def cell(text):
    return str(text).replace('|', '\\|').replace('\n', ' ')


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--pin', type=Path, required=True,
                        help="nightly_pin.py's output: report.json and pin.log")
    parser.add_argument('--scope', default='daily')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--jobs', type=Path, help='jobs JSON instead of the API (tests)')
    parser.add_argument('--logs', type=Path, help='a folder of <job id>.log (tests)')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    scale = float(os.environ.get('NIGHTLY_COMPARE_TOLERANCE_SCALE') or 1)
    repository = os.environ.get('GITHUB_REPOSITORY', '')
    report = json.loads((args.pin / 'report.json').read_text(encoding='utf-8'))
    log_path = args.pin / 'pin.log'
    pin_log = log_path.read_text(encoding='utf-8') if log_path.exists() else ''
    nightly, previous = report['nightly'], report['previous']

    if args.jobs:
        jobs = json.loads(args.jobs.read_text(encoding='utf-8'))
    else:
        jobs = run_jobs(repository, os.environ['GITHUB_RUN_ID'],
                        os.environ.get('GITHUB_RUN_ATTEMPT', '1'))

    def log_of(job):
        if job is None or job.get('conclusion') not in ('success', 'failure'):
            return ''
        if args.logs:
            path = args.logs / f"{job['id']}.log"
            return path.read_text(encoding='utf-8') if path.exists() else ''
        return gh('api', f"repos/{repository}/actions/jobs/{job['id']}/logs")

    rows, findings, details, saved = [], [], [], {}
    api_changes = report.get('api_changes') or []
    if api_changes:
        findings.append(f'C API changed: {", ".join(api_changes)}')
    for name, sides in pair_jobs(jobs).items():
        base, new = sides.get('baseline'), sides.get('nightly')
        # A job outside this run's scope (the release emulators in the daily set).
        if all(side and side.get('conclusion') == 'skipped' for side in (base, new)):
            continue
        verdict, notes = judge(base, new)
        a, b = records(log_of(base)), records(log_of(new))
        saved[name] = {'baseline': {' '.join(k): v for k, v in a.items()},
                       'nightly': {' '.join(k): v for k, v in b.items()}}
        drift, changed, only_base, only_new, worst = compare_records(a, b, scale)
        if verdict == 'regression':
            findings += [f'{name}: {note}' for note in notes if 'nightly only' in note]
        if drift:
            findings.append(f'{name}: {len(drift)} values beyond their tolerance')
            if verdict in ('same', 'fixed'):
                verdict = 'drift'
        if only_base and new and new.get('conclusion') == 'success':
            notes.append(f'{len(only_base)} records only on the baseline')
        if only_new:
            notes.append(f'{len(only_new)} records only on the nightly')
        if changed:
            notes.append(f'{len(changed)} other values changed')
        rows.append((name, base and base.get('conclusion'), new and new.get('conclusion'),
                     f'{len(a)} / {len(b)}', worst[1] or ('unchanged' if a else 'no records'),
                     verdict, notes))
        for key, field, x, y, move, limit in drift:
            details.append(f'| {cell(name)} | {cell(" ".join(key))} | {cell(field)} | {x} | '
                           f'{y} | {move:.3g} | {limit:.3g} |')
        for key, field, x, y in changed[:20]:
            details.append(f'| {cell(name)} | {cell(" ".join(key))} | {cell(field)} | '
                           f'{cell(x)} | {cell(y)} | changed | none |')

    verdicts = Counter(row[5] for row in rows)
    regression = any(row[5] in ('regression', 'drift') for row in rows)
    issue = bool(api_changes) or regression
    web = report.get('web') or {}
    comment_only = report.get('comment_only_headers') or []
    lines = [
        f'### Nightly {nightly} against the pinned {previous} ({args.scope} set)',
        '',
        f"Google's archive generation {report.get('generation')}. "
        + ('C API: **changed** (' + ', '.join(api_changes) + '); the nightly was not run.'
           if api_changes else
           'C API: unchanged' + (f' ({len(comment_only)} headers changed in comments only).'
                                 if comment_only else '.'))
        + f" Browser: {web.get('note', 'not pinned')}.",
        '',
    ]
    if rows:
        lines += ['| Suite | Baseline | Nightly | Records (baseline / nightly) | '
                  'Largest move, of its tolerance | Verdict |',
                  '|---|---|---|---|---|---|']
        for name, a, b, count, worst, verdict, notes in rows:
            text = verdict + (': ' + '; '.join(notes) if notes else '')
            lines.append(f'| {cell(name)} | {a} | {b} | {count} | {cell(worst)} | {cell(text)} |')
        lines.append('')
    summary = ', '.join(f'{count} {verdict}' for verdict, count in sorted(verdicts.items()))
    if issue:
        lines.append('**Findings:** ' + '; '.join(findings))
    elif rows:
        lines.append(f'**No drift.** {summary}.' + (
            ' Infrastructure failures are not the nightly; no issue.'
            if verdicts.get('infra') else ''))
    if scale != 1:
        lines.append(f'Tolerances scaled by {scale} (NIGHTLY_COMPARE_TOLERANCE_SCALE).')
    if details:
        lines += ['', '<details><summary>Values that moved</summary>', '',
                  '| Suite | Record | Field | Baseline | Nightly | Move | Tolerance |',
                  '|---|---|---|---|---|---|---|', *details[:150],
                  *([f'| {len(details) - 150} more rows in records.json |||||||']
                    if len(details) > 150 else []), '', '</details>']
    diff = header_diff(pin_log)
    if diff:
        lines += ['', '<details><summary>C header diff</summary>', '', '```diff',
                  *diff[:400], '```', '', '</details>']
    summary_text = '\n'.join(lines) + '\n'
    (args.out / 'summary.md').write_text(summary_text, encoding='utf-8')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as step:
            step.write(summary_text)
    print(summary_text)

    prefix = os.environ.get('NIGHTLY_COMPARE_ISSUE_PREFIX', '')
    title = f'{prefix}Nightly {nightly} differs from the pinned {previous}'
    run_url = (f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{repository}"
               f"/actions/runs/{os.environ.get('GITHUB_RUN_ID', '')}")
    (args.out / 'issue.md').write_text(
        f'Google\'s nightly {nightly} (archive generation {report.get("generation")}) '
        f'against the pinned {previous}, in [this run]({run_url}).\n\n' + summary_text,
        encoding='utf-8')
    (args.out / 'records.json').write_text(json.dumps(saved, indent=1) + '\n', encoding='utf-8')
    infra_only = bool(rows) and not issue and set(verdicts) == {'infra'}
    result = {'nightly': nightly, 'previous': previous, 'generation': report.get('generation'),
              'scope': args.scope, 'findings': findings, 'issue': issue,
              'escalate': regression, 'infra_only': infra_only, 'title': title,
              'verdicts': dict(verdicts)}
    (args.out / 'findings.json').write_text(json.dumps(result, indent=2) + '\n',
                                            encoding='utf-8')
    values = {'issue': str(issue).lower(), 'escalate': str(regression).lower(),
              'infra_only': str(infra_only).lower(), 'title': title}
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
            output.write(''.join(f'{key}={value}\n' for key, value in values.items()))


if __name__ == '__main__':
    main()

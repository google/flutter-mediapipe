"""Offline tests of nightly_compare.py and nightly_pin.py.

    python3 -B -m unittest tool/ci/test_nightly_compare.py
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
import unittest.mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import nightly_compare as compare  # noqa: E402
import nightly_pin as pin  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def job(id, name, conclusion='success', steps=()):
    return {'id': id, 'name': name, 'conclusion': conclusion, 'status': 'completed',
            'steps': [{'name': step, 'conclusion': result} for step, result in steps]}


class Tolerances(unittest.TestCase):
    def test_every_bound_matches_its_test(self):
        """A test that changes a tolerance changes the comparison too."""
        bounds = [bound for fields in compare.TOLERANCES.values() for bound in fields.values()]
        bounds += list(compare.REFERENCE.values())
        for bound in bounds:
            text = (REPO / bound.source).read_text(encoding='utf-8')
            match = re.search(bound.pattern, text)
            self.assertIsNotNone(match, f'{bound.source}: {bound.pattern}')
            self.assertEqual(float(match.group(1)), bound.limit, bound.source)

    def test_reference_bounds(self):
        key = ('MEDIAPIPE_REFERENCE_DELTAS', 'face_landmarker')
        self.assertEqual(compare.bound_for(
            key, 'gpu.face_blendshapes.maximum_absolute_error').limit, 0.04)
        self.assertEqual(compare.bound_for(
            key, 'cpu.face_landmarks.maximum_absolute_error').limit, 1e-4)
        self.assertEqual(compare.bound_for(
            ('MEDIAPIPE_REFERENCE_DELTAS', 'pose'),
            'gpu.world_landmarks.maximum_absolute_error').limit, 0.002)
        self.assertEqual(compare.bound_for(
            ('MEDIAPIPE_REFERENCE_DELTAS', 'image_classifier'),
            'cpu.categories.maximum_absolute_error').limit, 1e-5)
        self.assertIsNone(compare.bound_for(
            ('MEDIAPIPE_REFERENCE_DELTAS', 'pose'), 'gpu.landmarks.values'))
        self.assertEqual(compare.bound_for(
            ('SDK_SEGMENTER', ''), 'confidence_hair.mean').limit, 0.02)


class Records(unittest.TestCase):
    LOG = '\n'.join([
        '﻿2026-10-22T17:12:04.7292180Z Current runner version',
        '2026-10-22T17:20:00.1Z I/flutter ( 123): SDK_HAND_LANDMARKER {"event": "image", '
        '"delegate": "cpu", "official_max_delta": 0.001, "mean_inference_ms": 12.5}',
        '2026-10-22T17:20:01.1Z SDK_HAND_LANDMARKER {"event": "image", "delegate": "cpu", '
        '"official_max_delta": 0.002}',
        '2026-10-22T17:20:02.1Z MEDIAPIPE_REFERENCE_DELTAS pose {"gpu": {"landmarks": '
        '{"maximum_absolute_error": 0.0001, "values": 3, "path": "x"}}}',
        '2026-10-22T17:20:03.1Z \x1b[32m00:01 +1: LIVE_STREAM_VIDEO_DELTA 120 values, max 0.0\x1b[0m',
        '2026-10-22T17:20:04.1Z SDK_BROKEN {not json',
    ])

    def test_parses_markers_tags_and_occurrences(self):
        found = compare.records(self.LOG)
        self.assertEqual(sorted(found), sorted([
            ('SDK_HAND_LANDMARKER', '', 'event=image', 'delegate=cpu', '#1'),
            ('SDK_HAND_LANDMARKER', '', 'event=image', 'delegate=cpu', '#2'),
            ('MEDIAPIPE_REFERENCE_DELTAS', 'pose', '#1'),
            ('LIVE_STREAM_VIDEO_DELTA', '', '#1'),
        ]))
        self.assertEqual(found[('LIVE_STREAM_VIDEO_DELTA', '', '#1')], {'values': 120, 'max': 0.0})

    def test_timing_is_ignored_and_tolerances_apply(self):
        base = compare.records(self.LOG)
        new ={key: dict(value) for key, value in base.items()}
        hand = ('SDK_HAND_LANDMARKER', '', 'event=image', 'delegate=cpu', '#1')
        new[hand] = dict(base[hand], mean_inference_ms=99.0, official_max_delta=0.02)
        drift, changed, only_base, only_new, worst = compare.compare_records(base, new)
        self.assertEqual((drift, changed, only_base, only_new), ([], [], [], []))
        self.assertIn('official_max_delta', worst[1])
        new[hand]['official_max_delta'] = 0.05
        drift, *_ = compare.compare_records(base, new)
        self.assertEqual([(field, limit) for _, field, _, _, _, limit in drift],
                         [('official_max_delta', 0.03)])

    def test_floor_bounds_compare_their_slack(self):
        key = ('SDK_EMBEDDER', '', 'event=image', '#1')
        drift, *_ = compare.compare_records({key: {'event': 'image', 'official_cosine': 0.999}},
                                            {key: {'event': 'image', 'official_cosine': 0.995}})
        self.assertEqual(drift, [])
        drift, *_ = compare.compare_records({key: {'event': 'image', 'official_cosine': 0.999}},
                                            {key: {'event': 'image', 'official_cosine': 0.985}})
        self.assertEqual(len(drift), 1)

    def test_negative_scale_forces_drift(self):
        base = compare.records(self.LOG)
        drift, *_ = compare.compare_records(base, base, scale=-1)
        self.assertEqual(len(drift), 4)


class Judge(unittest.TestCase):
    def test_verdicts(self):
        suite = 'Run every package suite'
        ok = job(1, 'x (baseline)', steps=[('Set up job', 'success'), (suite, 'success')])
        bad = job(2, 'x (nightly)', 'failure', [('Set up job', 'success'), (suite, 'failure')])
        self.assertEqual(compare.judge(ok, ok)[0], 'same')
        verdict, notes = compare.judge(ok, bad)
        self.assertEqual(verdict, 'regression')
        self.assertIn('fails on the nightly only: ' + suite, notes)
        self.assertEqual(compare.judge(bad, bad)[0], 'infra')
        self.assertEqual(compare.judge(bad, ok)[0], 'fixed')
        flaky = job(3, 'x (nightly)', 'failure', [('Run ./.github/actions/setup', 'failure')])
        self.assertEqual(compare.judge(ok, flaky)[0], 'infra')
        self.assertEqual(compare.judge(ok, job(4, 'x', 'cancelled'))[0], 'infra')
        self.assertEqual(compare.judge(ok, None)[0], 'infra')

    def test_pairs_by_name_without_the_side(self):
        pairs = compare.pair_jobs([
            job(1, 'Desktop (baseline) / Vision tasks / ubuntu-24.04 x64 CPU'),
            job(2, 'Desktop (nightly) / Vision tasks / ubuntu-24.04 x64 CPU'),
            job(3, 'Pin the nightly'),
        ])
        self.assertEqual(list(pairs), ['Desktop / Vision tasks / ubuntu-24.04 x64 CPU'])
        self.assertEqual(sorted(pairs['Desktop / Vision tasks / ubuntu-24.04 x64 CPU']),
                         ['baseline', 'nightly'])


    def test_gh_allows_a_logs_colours_when_asked(self):
        calls = []

        def fake(arguments, **_):
            calls.append(arguments)
            refused = '--allow-escape-sequences' not in arguments
            return subprocess.CompletedProcess(
                arguments, 1 if refused else 0, '' if refused else 'log',
                'the response contains terminal escape sequences; pass '
                '--allow-escape-sequences to output it anyway' if refused else '')

        with unittest.mock.patch.object(compare.subprocess, 'run', fake):
            self.assertEqual(compare.gh('api', 'logs'), 'log')
        self.assertEqual(calls[1], ['gh', 'api', '--allow-escape-sequences', 'logs'])


class EndToEnd(unittest.TestCase):
    def run_compare(self, folder, jobs, logs, report, scale='1'):
        (folder / 'pin').mkdir()
        (folder / 'logs').mkdir()
        (folder / 'pin' / 'report.json').write_text(json.dumps(report))
        (folder / 'pin' / 'pin.log').write_text(
            'Headers: 1 changed\n    --- a/x.h\n    +++ b/x.h\n    -int a(void);\n    +int b(void);\n')
        (folder / 'jobs.json').write_text(json.dumps(jobs))
        for id, text in logs.items():
            (folder / 'logs' / f'{id}.log').write_text(text)
        # Not the workflow's own settings, which the pin job's run of these
        # tests inherits.
        env = dict(os.environ, NIGHTLY_COMPARE_TOLERANCE_SCALE=scale,
                   NIGHTLY_COMPARE_ISSUE_PREFIX='',
                   GITHUB_OUTPUT=str(folder / 'output'), GITHUB_STEP_SUMMARY='')
        subprocess.run([sys.executable, '-B', str(REPO / 'tool/ci/nightly_compare.py'),
                        '--pin', str(folder / 'pin'), '--out', str(folder / 'out'),
                        '--jobs', str(folder / 'jobs.json'), '--logs', str(folder / 'logs')],
                       check=True, env=env, capture_output=True)
        output = dict(line.split('=', 1) for line in
                      (folder / 'output').read_text().splitlines())
        return output, (folder / 'out' / 'summary.md').read_text()

    def test_outputs(self):
        report = {'nightly': '20261021', 'previous': '20261018', 'generation': '1',
                  'api_changes': [], 'web': {'note': 'browser runtimes moved'}}
        jobs = [job(1, 'D (baseline) / CPU'), job(2, 'D (nightly) / CPU'),
                # Outside the daily set: left out, not reported as infrastructure.
                job(3, 'A (baseline) / ${{ matrix.name }}', 'skipped'),
                job(4, 'A (nightly) / ${{ matrix.name }}', 'skipped')]
        logs = {1: Records.LOG, 2: Records.LOG}
        with tempfile.TemporaryDirectory() as folder:
            output, summary = self.run_compare(Path(folder), jobs, logs, report)
        self.assertEqual((output['issue'], output['infra_only']), ('false', 'false'))
        self.assertEqual(output['title'], 'Nightly 20261021 differs from the pinned 20261018')
        self.assertIn('| D / CPU | success | success | 4 / 4 |', summary)
        self.assertNotIn('matrix.name', summary)
        with tempfile.TemporaryDirectory() as folder:
            output, summary = self.run_compare(Path(folder), jobs, logs, report, '-1')
        self.assertEqual((output['issue'], output['escalate']), ('true', 'true'))
        api = dict(report, api_changes=['x.h'])
        with tempfile.TemporaryDirectory() as folder:
            output, summary = self.run_compare(Path(folder), [], {}, api)
        self.assertEqual((output['issue'], output['escalate']), ('true', 'false'))
        self.assertIn('+int b(void);', summary)


class Pin(unittest.TestCase):
    def test_scope(self):
        self.assertEqual(pin.scope_of('schedule', '0 14 * * 0', 'false'), 'full')
        self.assertEqual(pin.scope_of('schedule', '0 14 * * 1-6', 'false'), 'daily')
        self.assertEqual(pin.scope_of('workflow_dispatch', '', 'true'), 'full')
        self.assertEqual(pin.scope_of('pull_request', '', 'false'), 'daily')
        self.assertEqual(pin.scope_of('pull_request', '', 'true'), 'full')

    def test_the_weekly_schedule_is_the_workflows(self):
        workflow = (REPO / '.github/workflows/nightly-compare.yaml').read_text(encoding='utf-8')
        self.assertIn(f"cron: '{pin.FULL_SCHEDULE}'", workflow)

    def test_web_pins_name_one_version(self):
        pins = pin.runtime_pins()
        self.assertEqual(len(pins), 5)
        versions = {value['version'] for value in pins.values()}
        self.assertEqual(len(versions), 1)
        version = versions.pop()
        self.assertEqual(pin.web_version(version, '20261021'),
                         version.rpartition('-rc.')[0] + '-rc.20261021')
        for relative in pin.WEB_VERSION_NAMED:
            self.assertIn(f"'{version}'", (REPO / relative).read_text(encoding='utf-8'))
        for path, value in pins.items():
            # nightly_pin.py rewrites runtime.json with json.dumps(indent=2).
            self.assertEqual(path.read_text(encoding='utf-8'),
                             json.dumps(value, indent=2) + '\n', path)


if __name__ == '__main__':
    unittest.main()

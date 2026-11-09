"""Offline tests of nightly_compare.py and nightly_pin.py.

    python3 -B -m unittest tool/ci/test_nightly_compare.py
"""
import contextlib
import datetime
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
import unittest.mock
import urllib.error

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
        for relative in pin.WEB_VERSION_NAMED:
            self.assertIn(f"_webRuntimeVersion = '{version}'",
                          (REPO / relative).read_text(encoding='utf-8'))
        for path, value in pins.items():
            # nightly_pin.py rewrites runtime.json with json.dumps(indent=2).
            self.assertEqual(path.read_text(encoding='utf-8'),
                             json.dumps(value, indent=2) + '\n', path)

    def test_web_version_from_a_release_or_a_prerelease(self):
        self.assertEqual(pin.web_version('1.2.2', '20261105'), '1.2.2-rc.20261105')
        self.assertEqual(pin.web_version('1.2.2-rc.20261103', '20261105'), '1.2.2-rc.20261105')

    def test_npm_down_leaves_the_browser_pins(self):
        """npm failing after its retries costs the browser comparison, not
        the native one, and changes no file."""
        files = [*pin.runtime_pins(), *(REPO / relative for relative in pin.WEB_VERSION_NAMED)]
        before = {path: path.read_bytes() for path in files}
        down = urllib.error.HTTPError(pin.REGISTRY, 503, 'Service Unavailable', {}, None)
        with unittest.mock.patch('urllib.request.urlopen', side_effect=down) as urlopen, \
                unittest.mock.patch('time.sleep'):
            note, pinned = pin.pin_web('20261021')
        self.assertFalse(pinned)
        self.assertIn('npm failed', note)
        self.assertEqual(urlopen.call_count, len(pin.RETRY_DELAYS) + 1)
        self.assertEqual({path: path.read_bytes() for path in files}, before)

    def test_fetch_retries_only_what_may_pass(self):
        answer = unittest.mock.MagicMock()
        answer.__enter__.return_value.read.return_value = b'{}'
        dropped = urllib.error.URLError(ConnectionResetError('reset'))
        with unittest.mock.patch('urllib.request.urlopen',
                                 side_effect=[dropped, answer]) as urlopen, \
                unittest.mock.patch('time.sleep'):
            self.assertEqual(pin.fetch(pin.REGISTRY), b'{}')
        self.assertEqual(urlopen.call_count, 2)
        absent = urllib.error.HTTPError(pin.REGISTRY, 404, 'Not Found', {}, None)
        with unittest.mock.patch('urllib.request.urlopen', side_effect=absent) as urlopen:
            self.assertIsNone(pin.registry_entry('@mediapipe/tasks-vision', '0.0.0'))
        self.assertEqual(urlopen.call_count, 1)


class PinStop(unittest.TestCase):
    """nightly_pin.py's main, with a stand-in for pin_nightly.py."""
    STOP = {'version': '1.2.2', 'pinned': '1.2.0', 'since': '20261030'}

    def run_pin(self, day, status=1, stop=STOP, api_changes=None, event='schedule',
                nightly='newest', network_failure=None, network_failed_while=None,
                no_report=False):
        """The outputs, the step summary, what was printed and the failure, if any."""
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            report = {'nightly': '20261106', 'previous': '20261018', 'generation': '1',
                      'api_changes': api_changes, 'written': False}
            if stop:
                report['version_stop'] = stop
            if network_failure:
                report = {'network_failure': network_failure}
            if network_failed_while:
                report.update(network_failure=network_failure,
                              network_failed_while=network_failed_while)
            fake = folder / 'pin_nightly.py'
            write = '' if no_report else f"open(out, 'w').write({json.dumps(json.dumps(report))})\n"
            fake.write_text(f'import json, sys\n'
                            f"out = sys.argv[sys.argv.index('--report') + 1]\n"
                            f'{write}'
                            f'sys.exit({status})\n', encoding='utf-8')
            output, summary = folder / 'output', folder / 'summary'
            output.touch()
            summary.touch()
            argv = ['nightly_pin.py', '--nightly', nightly, '--event', event,
                    '--out', str(folder / 'out')]
            printed = io.StringIO()
            failure = None
            with unittest.mock.patch.object(pin, 'PIN_NIGHTLY', fake), \
                    unittest.mock.patch.object(pin, 'today', lambda: datetime.date(*day)), \
                    unittest.mock.patch.object(sys, 'argv', argv), \
                    unittest.mock.patch.dict(os.environ, {'GITHUB_OUTPUT': str(output),
                                                          'GITHUB_STEP_SUMMARY': str(summary)}), \
                    contextlib.redirect_stdout(printed):
                try:
                    pin.main()
                except SystemExit as error:
                    failure = str(error)
            lines = dict(line.split('=', 1) for line in output.read_text().splitlines())
            return lines, summary.read_text(), printed.getvalue(), failure

    def test_up_to_day_14_it_passes_with_no_annotation(self):
        for day, count in ((2026, 11, 6), 7), ((2026, 11, 13), 14):
            lines, summary, printed, failure = self.run_pin(day)
            self.assertIsNone(failure)
            self.assertEqual((lines['held'], lines['patched']), ('true', 'false'))
            self.assertNotIn('::warning::', printed)
            self.assertNotIn('::error::', printed)
            self.assertIn(f'{count} days behind, since 20261030', printed)
            self.assertIn(f'{count} days behind, since 20261030', summary)

    def test_from_day_15_to_day_90_it_warns_with_the_days_and_the_red_date(self):
        for day, count in ((2026, 11, 14), 15), ((2027, 1, 28), 90):
            lines, summary, printed, failure = self.run_pin(day)
            self.assertIsNone(failure)
            self.assertEqual(lines['held'], 'true')
            self.assertIn('::warning::The comparison is stopped', printed)
            self.assertIn(f'{count} days behind, since 20261030. Scheduled runs fail from '
                          '2027-01-29.', printed)
            self.assertIn(f'{count} days behind', summary)
            self.assertNotIn('::error::', printed)

    def test_from_day_91_a_scheduled_run_fails_by_name(self):
        lines, summary, printed, failure = self.run_pin((2027, 1, 29))
        self.assertIn('Nightly comparison stopped for over 90 days', failure)
        self.assertIn('91 days behind', failure)
        self.assertIn('::error::Nightly comparison stopped for over 90 days', printed)
        self.assertIn('Nightly comparison stopped for over 90 days', summary)
        self.assertEqual(lines, {})

    def test_a_dispatch_from_day_91_fails_too(self):
        self.assertIsNotNone(self.run_pin((2027, 1, 29), event='workflow_dispatch')[3])

    def test_a_pull_request_only_warns(self):
        for day, count in ((2026, 11, 13), 14), ((2027, 1, 29), 91), ((2027, 6, 1), 214):
            lines, _, printed, failure = self.run_pin(day, event='pull_request')
            self.assertIsNone(failure)
            self.assertEqual(lines['held'], 'true')
            self.assertNotIn('::error::', printed)
            self.assertEqual('::warning::' in printed, count > 14)

    def test_days_not_counted_warn_and_pass_on_any_date(self):
        unknown = dict(self.STOP, since=None)
        for day in (2026, 11, 6), (2027, 1, 29), (2030, 1, 1):
            lines, summary, printed, failure = self.run_pin(day, stop=unknown)
            self.assertIsNone(failure)
            self.assertEqual(lines['held'], 'true')
            self.assertIn('::warning::', printed)
            self.assertIn('could not be counted', printed)
            self.assertIn('could not be counted', summary)

    def test_a_night_asked_for_by_name_stays_a_failure(self):
        lines, summary, _, failure = self.run_pin((2026, 11, 6), nightly='20261103')
        self.assertEqual(failure, 'pin_nightly.py exited 1.')
        self.assertEqual((lines, summary), ({}, ''))

    def test_any_other_stop_stays_a_failure(self):
        lines, summary, _, failure = self.run_pin((2026, 11, 6), stop=None)
        self.assertEqual(failure, 'pin_nightly.py exited 1.')
        self.assertEqual((lines, summary), ({}, ''))

    def test_a_c_api_change_is_still_reported_and_not_held(self):
        lines, summary, _, failure = self.run_pin((2026, 11, 6), stop=None, api_changes=['x.h'])
        self.assertIsNone(failure)
        self.assertEqual((lines['api_changed'], lines['held'], summary), ('true', 'false', ''))

    def test_a_network_failure_warns_on_every_event_and_compares_nothing(self):
        for event, nightly in (('schedule', 'newest'), ('workflow_dispatch', 'newest'),
                               ('workflow_dispatch', '20261106'), ('pull_request', 'newest')):
            lines, summary, printed, failure = self.run_pin(
                (2027, 6, 1), event=event, nightly=nightly,
                network_failure='URLError: <urlopen error no route>')
            self.assertIsNone(failure)
            self.assertEqual(lines, {'network_failed': 'true'})
            self.assertNotIn('::error::', printed)
            self.assertIn(f'::warning::{self.NETWORK_NOTE}', printed)
            self.assertIn(self.NETWORK_NOTE, summary)

    def test_a_network_failure_reading_the_chosen_build_warns_naming_the_read(self):
        # pin_nightly keeps the rest of its report then; the network failure wins.
        for event in 'schedule', 'workflow_dispatch', 'pull_request':
            lines, summary, printed, failure = self.run_pin(
                (2027, 6, 1), event=event, stop=None, api_changes=[],
                network_failure='IncompleteRead: IncompleteRead(0 bytes read)',
                network_failed_while="hashing 20261106's vision/lib.so from its archive")
            self.assertIsNone(failure)
            self.assertEqual(lines, {'network_failed': 'true'})
            note = ("The comparison did not run: the network failed while hashing "
                    "20261106's vision/lib.so from its archive (IncompleteRead: "
                    'IncompleteRead(0 bytes read)). The next run tries again.')
            self.assertIn(f'::warning::{note}', printed)
            self.assertIn(note, summary)
            self.assertNotIn('::error::', printed)

    def test_a_run_that_chose_a_build_says_the_network_did_not_fail(self):
        self.assertEqual(self.run_pin((2026, 11, 6))[0]['network_failed'], 'false')

    def test_no_report_stays_a_failure_on_every_event(self):
        for event in 'schedule', 'workflow_dispatch', 'pull_request':
            lines, _, _, failure = self.run_pin((2026, 11, 6), event=event, no_report=True)
            self.assertIn('exited 1 and wrote no report', failure)
            self.assertEqual(lines, {})

    NETWORK_NOTE = ('The comparison did not run: the network failed while choosing Google\'s '
                    'build (URLError: <urlopen error no route>). The next run tries again.')


class WorkflowWithNoBuild(unittest.TestCase):
    """nightly-compare.yaml when the pin step set only network_failed, or held."""
    WORKFLOW = (REPO / '.github/workflows/nightly-compare.yaml').read_text(encoding='utf-8')

    def decide(self, **env):
        """The decide step's outputs and summary, run from the workflow's own script."""
        start = self.WORKFLOW.index('id: decide')
        block = self.WORKFLOW[self.WORKFLOW.index('run: |\n', start) + len('run: |\n'):]
        script = []
        for line in block.splitlines():
            if line.strip() and not line.startswith(' ' * 10):
                break
            script.append(line[10:])
        with tempfile.TemporaryDirectory() as temp:
            output, summary = Path(temp, 'output'), Path(temp, 'summary')
            output.touch()
            summary.touch()
            subprocess.run(['bash', '-e', '-c', '\n'.join(script)], check=True, env={
                'PATH': os.environ['PATH'], 'GITHUB_OUTPUT': str(output),
                'GITHUB_STEP_SUMMARY': str(summary), **env})
            return output.read_text(), summary.read_text()

    def test_it_reports_nothing_and_adds_nothing_to_the_summary(self):
        for env in {'NETWORK_FAILED': 'true'}, {'HELD': 'true', 'NETWORK_FAILED': 'false'}:
            self.assertEqual(self.decide(EVENT='pull_request', **env), ('report=false\n', ''))

    def test_with_a_build_it_still_reports(self):
        output, _ = self.decide(EVENT='pull_request', NETWORK_FAILED='false', HELD='false',
                                NIGHTLY='20261106', PREVIOUS='20261018', PATCHED='true')
        self.assertEqual(output, 'report=true\ncompare=true\n')

    def test_the_workflow_passes_the_outcome_to_the_decision(self):
        self.assertIn('NETWORK_FAILED: ${{ steps.pin.outputs.network_failed }}', self.WORKFLOW)
        self.assertIn('HELD: ${{ steps.pin.outputs.held }}', self.WORKFLOW)

    def jobs(self):
        """`{job: its if}`, read from the jobs section's own indentation."""
        body = self.WORKFLOW[self.WORKFLOW.index('\njobs:\n'):]
        found = {}
        for match in re.finditer(r'^  (\w+):\n(.*?)(?=^  \w+:\n|\Z)', body, re.M | re.S):
            condition = re.search(r'^    if: (.*)$', match.group(2), re.M)
            found[match.group(1)] = condition and condition.group(1)
        return found

    def test_every_later_job_needs_an_output_the_outcome_leaves_unset(self):
        jobs = self.jobs()
        self.assertEqual(set(jobs), {'pin', 'desktop', 'android', 'ios', 'macos', 'web',
                                     'compare', 'escalate'})
        self.assertIsNone(jobs.pop('pin'))
        for name in 'desktop', 'android', 'ios', 'macos', 'web':
            self.assertIn("needs.pin.outputs.compare == 'true'", jobs[name])
        self.assertIn("needs.pin.outputs.report == 'true'", jobs['compare'])
        self.assertIn("needs.compare.outputs.escalate == 'true'", jobs['escalate'])

    def test_the_pin_jobs_later_steps_skip_too(self):
        self.assertIn("if: ${{ github.event_name == 'schedule' && "
                      "steps.pin.outputs.network_failed != 'true' }}", self.WORKFLOW)
        upload = self.WORKFLOW[:self.WORKFLOW.index('name: nightly-pin\n')]
        self.assertIn("if: ${{ steps.decide.outputs.report == 'true' }}",
                      upload[upload.rindex('actions/upload-artifact') - 90:])


if __name__ == '__main__':
    unittest.main()

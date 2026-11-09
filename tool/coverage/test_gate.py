"""Unit tests for the coverage gate: python3 -B -m unittest tool/coverage/test_gate.py"""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gate  # noqa: E402

HERE = Path(__file__).resolve().parent


def result(returncode=0, stdout='', stderr=''):
    return subprocess.CompletedProcess(['gh'], returncode, stdout, stderr)


@contextlib.contextmanager
def fake_gh(answer):
    """Runs gate.gh against [answer], without waiting; yields the commands and the output."""
    commands = []

    def run(command, **_):
        commands.append(command[1:])
        return answer(command[1:])
    out, err = io.StringIO(), io.StringIO()
    with mock.patch.object(gate.subprocess, 'run', run), mock.patch.object(gate.time, 'sleep'), \
            contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        yield commands, out, err


class GateTest(unittest.TestCase):
    matrix = {'face_landmarker': {
        'web': {'cpu': 'required', 'gpu': 'pending: step 2'},
        'windows': {'cpu': 'required', 'gpu': 'unsupported: no GPU runtime'}}}

    def row(self, platform, delegate, passed=True, suite='s'):
        return dict(task='face_landmarker', platform=platform, delegate=delegate,
                    passed=passed, suite=suite)

    def test_required_cells_need_a_passing_row(self):
        states, failures, _, _ = gate.evaluate(self.matrix, [self.row('web', 'cpu')])
        self.assertEqual(states[('face_landmarker', 'web', 'cpu')], 'pass')
        self.assertEqual(failures, ['face_landmarker / windows / cpu: no row recorded'])

    def test_a_failing_row_names_its_suite(self):
        rows = [self.row('web', 'cpu'), self.row('windows', 'cpu', passed=False, suite='desktop')]
        _, failures, _, _ = gate.evaluate(self.matrix, rows)
        self.assertEqual(failures, ['face_landmarker / windows / cpu: failed in desktop'])

    def test_any_pass_satisfies_a_cell(self):
        rows = [self.row('web', 'cpu', passed=False), self.row('web', 'cpu'),
                self.row('windows', 'cpu')]
        _, failures, _, _ = gate.evaluate(self.matrix, rows)
        self.assertEqual(failures, [])

    def test_passing_pending_cells_are_reported_ahead(self):
        rows = [self.row('web', 'cpu'), self.row('windows', 'cpu'), self.row('web', 'gpu')]
        states, failures, ahead, _ = gate.evaluate(self.matrix, rows)
        self.assertEqual(failures, [])
        self.assertEqual(states[('face_landmarker', 'web', 'gpu')], 'ahead')
        self.assertEqual(len(ahead), 1)

    def test_matrix_covers_every_task_platform_and_delegate(self):
        matrix = gate.load_matrix()
        self.assertEqual(len(matrix), 23)
        for task, platforms in matrix.items():
            self.assertEqual(sorted(platforms), sorted(gate.PLATFORMS), task)
            for platform, delegates in platforms.items():
                self.assertEqual(sorted(delegates), ['cpu', 'gpu'], (task, platform))
                for status in delegates.values():
                    self.assertTrue(status in ('required', 'device') or status.startswith(
                        ('pending: ', 'unsupported: ')), status)

    def test_device_cells_need_device_rows(self):
        matrix = {'hand_landmarker': {'android': {'cpu': 'required', 'gpu': 'device'}}}
        cpu = dict(task='hand_landmarker', platform='android', delegate='cpu', passed=True, suite='e')
        gpu = dict(cpu, delegate='gpu', suite='emulator')
        # A pull-request row is not device evidence.
        states, failures, _, _ = gate.evaluate(matrix, [cpu, gpu])
        self.assertEqual(len(failures), 1)
        states, failures, _, awaiting = gate.evaluate(matrix, [cpu], strict_devices=False)
        self.assertEqual((failures, awaiting), ([], ['hand_landmarker / android / gpu']))
        self.assertEqual(states[('hand_landmarker', 'android', 'gpu')], 'awaiting')
        # A failed device run fails even a lenient gate.
        broken = dict(gpu, tier='device', passed=False, suite='akita')
        _, failures, _, _ = gate.evaluate(matrix, [cpu, broken], strict_devices=False)
        self.assertEqual(failures, ['hand_landmarker / android / gpu: failed in akita'])
        states, failures, _, _ = gate.evaluate(matrix, [cpu, dict(broken, passed=True)])
        self.assertEqual(failures, [])

    def test_a_device_workflow_missing_from_main_has_no_runs(self):
        # GitHub answers 404 for a workflow file the default branch lacks.
        def missing(*args):
            raise subprocess.CalledProcessError(1, ['gh', *args], stderr='gh: Not Found (HTTP 404)')
        original, gate.gh = gate.gh, missing
        try:
            self.assertEqual(gate.device_runs('owner/repo', []), {})
            gate.gh = lambda *args: (_ for _ in ()).throw(
                subprocess.CalledProcessError(1, ['gh'], stderr='HTTP 502'))
            with self.assertRaises(subprocess.CalledProcessError):
                gate.device_runs('owner/repo', [])
        finally:
            gate.gh = original

    def test_a_step_without_a_verdict_is_not_called_failed(self):
        for outcome in ('cancelled', 'skipped'):
            rows = [self.row('web', 'cpu'), dict(self.row('windows', 'cpu', passed=False, suite='d'),
                                                 outcome=outcome)]
            _, failures, _, _ = gate.evaluate(self.matrix, rows)
            self.assertEqual(failures, [f'face_landmarker / windows / cpu: {outcome} in d'])

    def test_a_test_lab_quota_miss_is_never_a_pass(self):
        # android-face-testlab.yml records outcome quota-exceeded when no test ran.
        matrix = {'hand_landmarker': {'android': {'gpu': 'device'}, 'macos': {'cpu': 'required'}}}
        with tempfile.TemporaryDirectory() as directory:
            for platform, delegate in (('android', 'gpu'), ('macos', 'cpu')):
                subprocess.run([sys.executable, '-B', str(HERE / 'record.py'), '--tier', 'device',
                                '--suite', platform, '--platform', platform, '--delegate', delegate,
                                '--tasks', 'hand_landmarker', '--outcome', 'quota-exceeded',
                                '--output-dir', directory], check=True, capture_output=True)
            rows = gate.load_rows(directory)
        self.assertFalse(any(r['passed'] for r in rows))
        for strict in (True, False):
            states, failures, _, awaiting = gate.evaluate(matrix, rows, strict_devices=strict)
            self.assertEqual(states[('hand_landmarker', 'android', 'gpu')], 'fail')
            self.assertEqual(states[('hand_landmarker', 'macos', 'cpu')], 'fail')
            self.assertEqual(awaiting, [])
            self.assertEqual(failures, ['hand_landmarker / android / gpu: quota-exceeded in android',
                                        'hand_landmarker / macos / cpu: quota-exceeded in macos'])

    def test_gh_tells_transient_failures_from_lasting_ones(self):
        for stderr in ('gh: Server Error (HTTP 502)', 'HTTP 503: Service Unavailable',
                       'gh: API rate limit exceeded (HTTP 403)',
                       'error connecting to api.github.com',
                       'Get "https://api.github.com": net/http: TLS handshake timeout',
                       'read tcp 10.1.0.4:1->140.82.1.1:443: read: connection reset by peer',
                       'dial tcp: lookup api.github.com on 127.0.0.53:53: server misbehaving',
                       'error writing zip archive: unexpected EOF',
                       'error downloading coverage-x: error extracting zip archive: zip: not a valid zip file'):
            self.assertTrue(gate.TRANSIENT_GH.search(stderr), stderr)
        for stderr in ('gh: Not Found (HTTP 404)', 'gh: Bad credentials (HTTP 401)',
                       'gh: Resource not accessible by integration (HTTP 403)',
                       'no valid artifacts found to download',
                       'no artifact matches any of the names or patterns provided',
                       'error downloading coverage-x: error extracting zip archive: error extracting '
                       '"x.json": open build/coverage-rows/1/coverage-x/x.json: file exists'):
            self.assertFalse(gate.TRANSIENT_GH.search(stderr), stderr)

    def test_gh_prints_stderr_and_does_not_retry_a_lasting_failure(self):
        with fake_gh(lambda _: result(1, stderr='gh: Not Found (HTTP 404)')) as (commands, out, err):
            with self.assertRaises(subprocess.CalledProcessError) as raised:
                gate.gh('api', 'repos/o/r')
        self.assertEqual(raised.exception.stderr, 'gh: Not Found (HTTP 404)')
        self.assertEqual(len(commands), 1)
        self.assertIn('gh api repos/o/r: gh: Not Found (HTTP 404)', err.getvalue())
        self.assertNotIn('::warning::', out.getvalue())

    def test_gh_warns_on_each_retry_and_returns_the_answer(self):
        answers = [result(1, stderr='HTTP 502'), result(1, stderr='line\nHTTP 503'), result(stdout='ok')]
        with fake_gh(lambda _: answers.pop(0)) as (commands, out, err):
            self.assertEqual(gate.gh('api', 'repos/o/r'), 'ok')
        self.assertEqual(len(commands), 3)
        self.assertEqual(out.getvalue().splitlines(),
                         ['::warning::gh api repos/o/r failed, retrying in 15 s: HTTP 502',
                          '::warning::gh api repos/o/r failed, retrying in 30 s: HTTP 503'])
        self.assertIn('HTTP 502', err.getvalue())

    def test_gh_gives_up_after_three_retries(self):
        with fake_gh(lambda _: result(1, stderr='HTTP 502')) as (commands, out, _):
            with self.assertRaises(subprocess.CalledProcessError):
                gate.gh('api', 'repos/o/r')
        self.assertEqual(len(commands), 4)
        self.assertEqual(out.getvalue().count('::warning::'), 3)

    def test_a_retried_download_starts_from_an_empty_directory(self):
        # gh run download refuses to overwrite: a retry over a partial attempt
        # would turn a dropped connection into a lasting "file exists".
        def download(command):
            if command[:2] == ['run', 'download']:
                target = Path(command[command.index('--dir') + 1], 'coverage-x')
                if target.exists():
                    return result(1, stderr=f'open {target}/x.json: file exists')
                target.mkdir(parents=True)
                (target / 'x.json').write_text('[]')
                if len(downloads) == 0:
                    downloads.append(command)
                    return result(1, stderr='error writing zip archive: unexpected EOF')
                return result()
            if 'head_sha=' in command[1]:
                return result(stdout=json.dumps({'workflow_runs': [
                    dict(id=7, path=path, event='push', status='completed', conclusion='success')
                    for path in gate.RECORDING_WORKFLOWS[:1]]}))
            if command[1].endswith('artifacts?per_page=100'):
                return result(stdout=json.dumps({'artifacts': [{'name': 'coverage-x'}]}))
            return result(1, stderr='gh: Not Found (HTTP 404)')
        downloads = []
        with tempfile.TemporaryDirectory() as directory, \
                mock.patch.object(gate, 'RECORDING_WORKFLOWS', gate.RECORDING_WORKFLOWS[:1]), \
                mock.patch.dict(os.environ, GITHUB_REPOSITORY='o/r'), fake_gh(download) as (_, out, _):
            runs = gate.collect('sha', Path(directory), 1)
            self.assertEqual(json.loads((Path(directory) / '7/coverage-x/x.json').read_text()), [])
        self.assertEqual(list(runs), gate.RECORDING_WORKFLOWS[:1])
        self.assertEqual(out.getvalue().count('::warning::'), 1)

    RUNS = {'.github/workflows/main.yaml': {'id': 41703032863}}
    # Job 126151609411, as GitHub reports it.
    UNACQUIRED = dict(id=126151609411, name='Modern text tasks / fresh macOS consumer',
                      conclusion='cancelled', steps=[], html_url='https://example.test/job')
    NOT_ACQUIRED = 'The job was not acquired by Runner of type hosted even after multiple attempts'

    def jobs_answer(self, jobs, annotations=None):
        def answer(command):
            if '/check-runs/' in command[1]:
                if annotations is None:
                    return result(1, stderr='gh: Resource not accessible by integration (HTTP 403)')
                return result(stdout=json.dumps(annotations))
            return result(stdout=json.dumps({'jobs': jobs}))
        return answer

    def run_main(self, runs, rows, answer):
        """gate.main over [rows] on self.matrix: its report, and its exit message or None."""
        unsupported = {'cpu': 'unsupported: x', 'gpu': 'unsupported: x'}
        matrix = {'face_landmarker': {**{p: unsupported for p in gate.PLATFORMS},
                                      **self.matrix['face_landmarker']}}
        with tempfile.TemporaryDirectory() as directory, \
                mock.patch.object(gate, 'load_matrix', lambda: matrix), \
                mock.patch.object(gate, 'collect', lambda *_: runs), \
                mock.patch.object(sys, 'argv', ['gate.py', '--collect', '--rows', directory]), \
                mock.patch.dict(os.environ, GITHUB_REPOSITORY='o/r'), fake_gh(answer) as (commands, out, _):
            os.environ.pop('GITHUB_STEP_SUMMARY', None)
            (Path(directory) / 'rows.json').write_text(json.dumps(rows))
            try:
                gate.main()
                code = None
            except SystemExit as error:
                code = error.code
        return out.getvalue(), code, commands

    def test_missing_cells_name_the_job_that_stopped_and_why(self):
        rows = [self.row('web', 'cpu')]
        annotations = [dict(annotation_level='notice', message='Due to capacity constraints'),
                       dict(annotation_level='failure', message=self.NOT_ACQUIRED)]
        report, code, _ = self.run_main(self.RUNS, rows, self.jobs_answer(
            [self.UNACQUIRED, dict(self.UNACQUIRED, id=1, name='Passed', conclusion='success'),
             dict(self.UNACQUIRED, id=2, name='Tests', conclusion='failure')], annotations))
        self.assertIn('face_landmarker / windows / cpu: no row recorded', report)
        self.assertIn('- main.yaml / Modern text tasks / fresh macOS consumer: cancelled with no '
                      f'step run: {self.NOT_ACQUIRED} (https://example.test/job)', report)
        self.assertNotIn('Passed', report)
        self.assertNotIn('Tests', report)
        self.assertEqual(code, '1 required cells have no passing row')

    def test_a_job_that_ran_and_an_unreadable_annotation_are_still_named(self):
        job = dict(self.UNACQUIRED, conclusion='timed_out', steps=[{'name': 'Tests'}])
        report, code, _ = self.run_main(self.RUNS, [self.row('web', 'cpu')], self.jobs_answer([job]))
        self.assertIn('fresh macOS consumer: timed_out: GitHub gave no reason', report)
        self.assertEqual(code, '1 required cells have no passing row')

    def test_missing_cells_without_a_stopped_job_say_so(self):
        report, code, _ = self.run_main(self.RUNS, [self.row('web', 'cpu')], self.jobs_answer([]))
        self.assertIn('No job on the runs read was cancelled or timed out', report)
        self.assertEqual(code, '1 required cells have no passing row')

    def test_the_gate_stays_red_when_the_jobs_cannot_be_read(self):
        report, code, commands = self.run_main(self.RUNS, [self.row('web', 'cpu')],
                                               lambda _: result(1, stderr='HTTP 502'))
        self.assertIn('- Could not list the jobs: HTTP 502', report)
        self.assertEqual(len(commands), 4)
        self.assertEqual(code, '1 required cells have no passing row')

    def test_jobs_are_only_read_for_cells_with_no_row(self):
        # Every cell passes, or names its suite: nothing to explain, and a lookup
        # never made cannot turn a passing gate red.
        rows = [self.row('web', 'cpu'), self.row('windows', 'cpu')]
        report, code, commands = self.run_main(self.RUNS, rows, lambda _: result(1, stderr='HTTP 502'))
        self.assertEqual((code, commands), (None, []))
        rows = [self.row('web', 'cpu'), self.row('windows', 'cpu', passed=False, suite='desktop')]
        report, code, commands = self.run_main(self.RUNS, rows, lambda _: result(1, stderr='HTTP 502'))
        self.assertEqual(commands, [])
        self.assertIn('failed in desktop', report)
        self.assertEqual(code, '1 required cells have no passing row')

    def test_record_refuses_unsupported_cells(self):
        with tempfile.TemporaryDirectory() as directory:
            command = [sys.executable, '-B', str(HERE / 'record.py'), '--suite', 'x',
                       '--platform', 'windows', '--delegate', 'gpu', '--tasks', 'face_landmarker',
                       '--outcome', 'success', '--output-dir', directory]
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
            command[command.index('gpu')] = 'cpu'
            subprocess.run(command, check=True, capture_output=True)
            rows = json.loads((Path(directory) / 'x.json').read_text())
            self.assertEqual(rows[0]['passed'], True)


if __name__ == '__main__':
    unittest.main()

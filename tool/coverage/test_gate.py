"""Unit tests for the coverage gate: python3 -B -m unittest tool/coverage/test_gate.py"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gate  # noqa: E402

HERE = Path(__file__).resolve().parent


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
        self.assertEqual(len(matrix), 21)
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

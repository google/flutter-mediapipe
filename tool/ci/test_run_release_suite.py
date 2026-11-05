"""Unit tests for the release suite runner: python3 -B -m unittest tool/ci/test_run_release_suite.py"""
import io
import os
from pathlib import Path
import subprocess
import sys
import time
import types
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_release_suite  # noqa: E402


def silent_process(test):
    """A process that stays running and prints nothing."""
    read, write = os.pipe()
    test.addCleanup(os.close, write)
    stdout = os.fdopen(read, 'rb')
    return types.SimpleNamespace(stdout=stdout)


def printing(*lines):
    return types.SimpleNamespace(stdout=io.BytesIO(''.join(f'{line}\n' for line in lines).encode()))


class VerdictTest(unittest.TestCase):
    def setUp(self):
        for name, value in (('POLL', 0.01), ('SILENCE', 0.1)):
            patcher = mock.patch.object(run_release_suite, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        out = mock.patch('sys.stdout', io.StringIO())
        out.start()
        self.addCleanup(out.stop)

    def test_reads_either_verdict(self):
        for line in 'All tests passed!', 'Some tests failed.':
            self.assertEqual(run_release_suite.verdict(printing('00:01 +1: a', f'00:02 +1: {line}'), 60), line)

    def test_output_that_ends_without_a_verdict_is_none(self):
        self.assertIsNone(run_release_suite.verdict(printing('00:01 +1: a'), 60))

    def test_a_dead_app_ends_the_wait(self):
        started = time.monotonic()
        self.assertIsNone(run_release_suite.verdict(silent_process(self), 60, lambda: True))
        self.assertLess(time.monotonic() - started, 5)

    def test_silence_ends_the_wait_on_android(self):
        started = time.monotonic()
        self.assertIsNone(run_release_suite.verdict(silent_process(self), 60, lambda: False))
        self.assertLess(time.monotonic() - started, 5)

    def test_a_desktop_run_waits_out_its_timeout(self):
        started = time.monotonic()
        self.assertIsNone(run_release_suite.verdict(silent_process(self), 0.3))
        self.assertGreaterEqual(time.monotonic() - started, 0.3)


class DeathCheckTest(unittest.TestCase):
    def check(self, *replies):
        def run(*_, **__):
            reply = next(answers)
            if isinstance(reply, Exception):
                raise reply
            return types.SimpleNamespace(stdout=reply)
        answers = iter(replies)
        patcher = mock.patch.object(run_release_suite.subprocess, 'run', run)
        patcher.start()
        self.addCleanup(patcher.stop)
        return run_release_suite.death_check(['adb'])

    def test_needs_two_misses_in_a_row_after_the_app_was_seen(self):
        dead = self.check('123\n', '', '123\n', '', '')
        self.assertEqual([dead() for _ in range(5)], [False, False, False, False, True])

    def test_an_app_never_seen_is_not_called_dead(self):
        dead = self.check('', '', '', '')
        self.assertEqual([dead() for _ in range(4)], [False] * 4)

    def test_an_unresponsive_device_counts_as_a_miss(self):
        hung = subprocess.TimeoutExpired('adb', 30)
        dead = self.check('123\n', hung, hung)
        self.assertEqual([dead() for _ in range(3)], [False, False, True])


class ExitCodeTest(unittest.TestCase):
    def run_main(self, process, dead=None, target=('--target', 'linux')):
        args = ['run_release_suite.py', *target, '--suite', 'a.dart', '--timeout', '1']
        with mock.patch.object(sys, 'argv', args), \
                mock.patch.object(run_release_suite, 'build'), \
                mock.patch.object(run_release_suite, 'launch', return_value=(process, lambda: None, dead)), \
                mock.patch('sys.stdout', io.TextIOWrapper(io.BytesIO())), \
                self.assertRaises(SystemExit) as caught:
            run_release_suite.main()
        return caught.exception.code

    def test_only_a_passing_report_exits_zero(self):
        self.assertEqual(self.run_main(printing('All tests passed!')), 0)
        self.assertEqual(self.run_main(printing('Some tests failed.')), 1)

    def test_no_report_exits_nonzero(self):
        self.assertEqual(self.run_main(printing('00:01 +1: a')), 1)

    def test_a_hung_device_still_exits_nonzero(self):
        android = ('--target', 'android', '--device', 'emulator-5554')
        hung = subprocess.TimeoutExpired('adb', 60)
        with mock.patch.object(run_release_suite.subprocess, 'run', side_effect=hung) as run:
            self.assertEqual(self.run_main(printing('00:01 +1: a'), target=android), 1)
        self.assertIn('logcat', run.call_args.args[0])


if __name__ == '__main__':
    unittest.main()

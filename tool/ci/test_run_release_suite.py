"""Unit tests for the release suite runner: python3 -B -m unittest tool/ci/test_run_release_suite.py"""
import io
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import types
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_release_suite  # noqa: E402


def silent_process(test, *lines):
    """A process that prints [lines], then stays running and prints nothing."""
    read, write = os.pipe()
    test.addCleanup(os.close, write)
    os.write(write, ''.join(f'{line}\n' for line in lines).encode())
    stdout = os.fdopen(read, 'rb')
    return types.SimpleNamespace(stdout=stdout)


def printing(*lines):
    return types.SimpleNamespace(stdout=io.BytesIO(''.join(f'{line}\n' for line in lines).encode()))


def repeating(test, line):
    """A process that prints [line] every 10 ms until the test ends, with its
    count in place of any {}."""
    def lines():
        count = 0
        while not ended.is_set():
            time.sleep(0.01)
            count += 1
            yield f'{line.format(count)}\n'.encode()
    ended = threading.Event()
    test.addCleanup(ended.set)
    return types.SimpleNamespace(stdout=lines())


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

    def assert_silence_ends(self, process, last):
        started = time.monotonic()
        self.assertIsNone(run_release_suite.verdict(process, 10, lambda: False))
        self.assertLess(time.monotonic() - started, 5)
        out = sys.stdout.getvalue()
        self.assertIn('silent for over', out)
        self.assertRegex(out, f'Its last download line: {last}')

    # With lines this frequent, no wait for a line ever runs out.
    @mock.patch.object(run_release_suite, 'POLL', 60)
    def test_a_repeated_download_line_does_not_hold_off_silence_and_it_names_the_last(self):
        line = 'MODEL_DOWNLOAD laya_s256.task: 300 of 678 MB in 968 s'
        self.assert_silence_ends(repeating(self, line), line)

    @mock.patch.object(run_release_suite, 'POLL', 60)
    def test_an_answer_with_no_bytes_does_not_hold_off_silence(self):
        line = 'MODEL_DOWNLOAD laya_s256.task: HTTP 200, 678 MB'
        self.assert_silence_ends(repeating(self, line), line)

    @mock.patch.object(run_release_suite, 'POLL', 60)
    def test_an_unreadable_download_line_does_not_hold_off_silence(self):
        line = 'MODEL_DOWNLOAD laya_s256.task: {} MB left'
        self.assert_silence_ends(repeating(self, line), 'MODEL_DOWNLOAD laya_s256.task: [0-9]+ MB left')

    def test_a_stall_after_a_download_ended_is_silence_and_it_names_the_end(self):
        ended = 'MODEL_DOWNLOAD laya_s256.task: 678 of 678 MB in 2180 s, ended'
        process = silent_process(self, 'MODEL_DOWNLOAD laya_s256.task: HTTP 200, 678 MB', ended)
        self.assert_silence_ends(process, ended)

    def test_download_progress_holds_off_silence(self):
        line = 'MODEL_DOWNLOAD laya_s256.task: {} of 678 MB in 9 s'
        with mock.patch.object(run_release_suite, 'SILENCE', 1):
            self.assertIsNone(run_release_suite.verdict(repeating(self, line), 2, lambda: False))
        self.assertNotIn('silent', sys.stdout.getvalue())

    def test_the_timeout_ends_a_download_that_keeps_progressing_and_names_it(self):
        line = 'MODEL_DOWNLOAD laya_s256.task: {} of 678 MB in 9 s'
        started = time.monotonic()
        self.assertIsNone(run_release_suite.verdict(repeating(self, line), 0.3))
        self.assertGreaterEqual(time.monotonic() - started, 0.3)
        self.assertLess(time.monotonic() - started, 30)
        self.assertRegex(sys.stdout.getvalue(), 'Its last download line: MODEL_DOWNLOAD laya_s256.task: [0-9]+ of 678')

    def test_only_more_megabytes_for_that_file_are_progress(self):
        received = {}
        for line, expected in (
            ('00:01 +1: a', True),
            ('MODEL_DOWNLOAD a.task: HTTP 200, 678 MB', False),
            ('MODEL_DOWNLOAD a.task: 100 of 678 MB in 322 s', True),
            ('MODEL_DOWNLOAD a.task: 100 of 678 MB in 322 s', False),
            ('MODEL_DOWNLOAD a.task: 99 of 678 MB in 322 s', False),
            ('MODEL_DOWNLOAD a.task: 200 of 678 MB in 644 s', True),
            ('MODEL_DOWNLOAD b.task: 100 MB in 9 s', True),
            ('MODEL_DOWNLOAD a.task: 200 of 678 MB in 700 s, ended', False),
            # A resumed download's answer counts from zero again.
            ('MODEL_DOWNLOAD a.task: HTTP 206, 478 MB', False),
            ('MODEL_DOWNLOAD a.task: 0 of 478 MB in 60 s, ended', False),
            ('MODEL_DOWNLOAD a.task: 100 of 478 MB in 322 s', True),
            ('MODEL_DOWNLOAD a.task: 478 of 478 MB in 999 s, ended', True),
            ('MODEL_DOWNLOAD a.task: 9000 of everything', False),
        ):
            self.assertEqual(run_release_suite.heard_from(line, received), expected, line)

    def test_a_dead_app_ends_the_wait_during_a_download(self):
        process = silent_process(self, 'MODEL_DOWNLOAD laya_s256.task: 300 of 678 MB in 968 s')
        self.assertIsNone(run_release_suite.verdict(process, 60, lambda: True))
        self.assertIn('The app or its device has gone.', sys.stdout.getvalue())

    def test_other_lines_still_hold_off_silence(self):
        with mock.patch.object(run_release_suite, 'SILENCE', 1):
            self.assertIsNone(run_release_suite.verdict(repeating(self, '00:01 +1: a'), 2, lambda: False))
        self.assertNotIn('silent', sys.stdout.getvalue())

    def test_a_download_line_is_no_verdict_and_leaves_one_readable(self):
        process = printing('MODEL_DOWNLOAD a.task: HTTP 200, of 1 MB', 'All tests passed!')
        self.assertEqual(run_release_suite.verdict(process, 60, lambda: False), 'All tests passed!')

    def test_silence_without_a_download_names_none(self):
        self.assertIsNone(run_release_suite.verdict(silent_process(self), 60, lambda: False))
        self.assertIn('silent for over', sys.stdout.getvalue())
        self.assertNotIn('download', sys.stdout.getvalue())

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


# From the build logs of jobs 115996940001 and 116031028600.
HTTP_500 = ('Verified download failed: https://github.com/a/b/releases/download/c/d.so: '
            'HttpException: HTTP 500, uri = https://github.com/a/b/releases/download/c/d.so')
ZIP = ('Warning: An error occurred while preparing SDK package NDK (Side by side) '
       '28.2.13676358: Error on ZipFile unknown archive.')
# The same client's words in job 116023056045's test phase.
LOOKUP = ("Verified download failed: https://storage.googleapis.com/a/b.so: ClientException "
          "with SocketException: Failed host lookup: 'storage.googleapis.com' (OS Error: "
          "No address associated with hostname, errno = 7), uri=https://storage.googleapis.com/")


class BuildTest(unittest.TestCase):
    def build(self, *runs):
        """build() over (status, lines) per run; returns the commands run, what
        was printed, and the failure's exit status, if any."""
        answers = iter(runs)
        commands = []

        def popen(command, **_):
            commands.append(command)
            status, lines = next(answers)
            return types.SimpleNamespace(stdout=printing(*lines).stdout, wait=lambda: status)
        args = types.SimpleNamespace(define=[], target='android', suite='a.dart',
                                     android_platform='android-x64')
        printed = io.StringIO()
        status = None
        with mock.patch.object(run_release_suite.subprocess, 'Popen', popen), \
                mock.patch.object(run_release_suite.time, 'sleep') as sleep, \
                mock.patch('sys.stdout', printed):
            try:
                run_release_suite.build(args)
            except subprocess.CalledProcessError as error:
                status = error.returncode
        self.assertEqual(sleep.call_count, max(len(commands) - 1, 0))
        return commands, printed.getvalue(), status

    def test_a_clean_build_runs_once(self):
        commands, printed, status = self.build((0, ['Built app-release.apk']))
        self.assertEqual((len(commands), status), (1, None))
        self.assertIn('Built app-release.apk', printed)
        self.assertNotIn('::warning::', printed)

    def test_a_network_error_builds_once_more_and_warns(self):
        for line in (HTTP_500, ZIP, LOOKUP,
                     'Verified download failed: https://a/b.so: SocketException: Connection reset',
                     'Verified download failed: https://a/b.so: TimeoutException after 0:01:00.000000'):
            commands, printed, status = self.build((1, [line, 'BUILD FAILED in 4m 3s']),
                                                   (0, ['Built']))
            self.assertEqual((len(commands), status), (2, None), line)
            self.assertEqual(commands[0], commands[1])
            self.assertIn('::warning::', printed)
            self.assertIn(line, printed)

    def test_a_second_network_error_is_red(self):
        commands, _, status = self.build((1, [HTTP_500]), (7, [HTTP_500]), (0, []))
        self.assertEqual((len(commands), status), (2, 7))

    def test_a_second_failure_of_another_kind_is_red(self):
        commands, _, status = self.build((1, [HTTP_500]), (1, ['Error: boom']), (0, []))
        self.assertEqual((len(commands), status), (2, 1))

    def test_any_other_build_error_is_red_at_once(self):
        for line in ("lib/main.dart:3:1: Error: Expected ';' after this.",
                     'Verified download failed: https://a/b.so: SHA-256 mismatch',
                     'Verified download failed: https://a/b.so: HttpException: HTTP 404, uri = https://a/b.so',
                     'Verified download failed: https://a/b.so: HttpException: HTTP 403, uri = https://a/b.so',
                     'Verified download failed: https://a/b.so: ClientException: Redirect limit exceeded',
                     "lib/main.dart:3:1: Error: Undefined name 'SocketException'.",
                     'lib/main.dart:4:1: Error: HTTP 500 is not a type.',
                     'Verified download failed: https://a/b.so: HandshakeException: certificate',
                     'FAILURE: Build failed with an exception.'):
            commands, printed, status = self.build((1, [line]), (0, []))
            self.assertEqual((len(commands), status), (1, 1), line)
            self.assertNotIn('::warning::', printed)

    def test_network_words_in_a_build_that_passed_do_not_rebuild(self):
        commands, printed, status = self.build((0, [HTTP_500]))
        self.assertEqual((len(commands), status), (1, None))
        self.assertNotIn('::warning::', printed)


class ExitCodeTest(unittest.TestCase):
    def run_main(self, process, dead=None, target=('--target', 'linux')):
        args = ['run_release_suite.py', *target, '--suite', 'a.dart', '--timeout', '1']
        raw = io.BytesIO()
        out = io.TextIOWrapper(raw, write_through=True)
        with mock.patch.object(sys, 'argv', args), \
                mock.patch.object(run_release_suite, 'build'), \
                mock.patch.object(run_release_suite, 'launch', return_value=(process, lambda: None, dead)), \
                mock.patch('sys.stdout', out), \
                self.assertRaises(SystemExit) as caught:
            run_release_suite.main()
        self.out = raw.getvalue().decode()
        return caught.exception.code

    def test_only_a_passing_report_exits_zero(self):
        self.assertEqual(self.run_main(printing('All tests passed!')), 0)
        self.assertEqual(self.run_main(printing('Some tests failed.')), 1)

    def test_a_failed_test_after_a_download_exits_nonzero(self):
        report = printing('MODEL_DOWNLOAD laya_s256.task: 678 of 678 MB in 2180 s, ended',
                          'Bad state: SHA-256 mismatch for laya_s256.task',
                          '00:01 +0 -1: Decision Maker answers [E]',
                          'Some tests failed.')
        self.assertEqual(self.run_main(report, lambda: False), 1)
        self.assertIn('SHA-256 mismatch for laya_s256.task', self.out)
        self.assertIn('in release on linux: Some tests failed.', self.out)

    def test_a_run_past_its_timeout_exits_nonzero_and_says_why(self):
        process = silent_process(self, 'MODEL_DOWNLOAD laya_s256.task: 300 of 678 MB in 968 s')
        self.assertEqual(self.run_main(process), 1)
        self.assertIn('Its last download line: MODEL_DOWNLOAD laya_s256.task: 300 of 678 MB in 968 s', self.out)
        self.assertIn('a.dart reported no verdict in release within 1 s.', self.out)

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

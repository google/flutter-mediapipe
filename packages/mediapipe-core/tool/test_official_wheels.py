"""Unit tests for installing the official wheel, offline, on pip's real output:
python3 -B -m unittest packages/mediapipe-core/tool/test_official_wheels.py"""
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import official_wheels  # noqa: E402

OK = 'Successfully installed mediapipe-nightly\n'
READ_TIMEOUT = """\
  Downloading mediapipe_nightly-1.1.0rc20260925-py3-none-win_amd64.whl (21.3 MB)
ERROR: Exception:
Traceback (most recent call last):
    raise ReadTimeoutError(self._pool, None, "Read timed out.")
pip._vendor.urllib3.exceptions.ReadTimeoutError: \
HTTPSConnectionPool(host='files.pythonhosted.org', port=443): Read timed out.
"""
DNS = """\
  WARNING: Retrying (Retry(total=0, connect=None, read=None, redirect=None, status=None)) after \
connection broken by 'NewConnectionError('Failed to establish a new connection: [Errno 8] \
nodename nor servname provided, or not known')': /m.whl
ERROR: Could not install packages due to an OSError: HTTPSConnectionPool(host='x', port=443): \
Max retries exceeded with url: /m.whl (Caused by NewConnectionError('Failed to establish'))
"""
SERVER_ERRORS = """\
ERROR: Could not install packages due to an OSError: HTTPConnectionPool(host='x', port=80): \
Max retries exceeded with url: /m.whl (Caused by ResponseError('too many 503 error responses'))
"""
RATE_LIMIT = '  ERROR: HTTP error 429 while getting https://x/m.whl#sha256=ab\n'
INDEX_DOWN = """\
WARNING: Retrying (Retry(total=0, connect=None, read=None, redirect=None, status=None)) after \
connection broken by 'NewConnectionError('Failed to establish a new connection')': /simple/numpy/
ERROR: Could not find a version that satisfies the requirement numpy (from versions: none)
ERROR: No matching distribution found for numpy
"""
HASH_MISMATCH = """\
ERROR: THESE PACKAGES DO NOT MATCH THE HASHES FROM THE REQUIREMENTS FILE. If you have updated the \
package versions, please update the hashes.
        Expected sha256 aaaa
             Got        dc90
"""
BAD_VERSION = """\
ERROR: Could not find a version that satisfies the requirement numpy==9.9 (from versions: none)
ERROR: No matching distribution found for numpy==9.9
"""
MISSING = """\
  ERROR: HTTP error 404 while getting https://x/m.whl#sha256=ab
ERROR: Could not install requirement m from https://x/m.whl#sha256=ab because of HTTP error 404 \
Client Error: Not Found for url: https://x/m.whl
"""
UNSUPPORTED = 'ERROR: m-1.0-cp27-none-win32.whl is not a supported wheel on this platform.\n'
RECOVERED = """\
  WARNING: Retrying (Retry(total=4, connect=None, read=None, redirect=None, status=None)) after \
connection broken by 'ReadTimeoutError("HTTPSConnectionPool(host='x', port=443): Read timed out. \
(read timeout=15)")': /simple/numpy/
"""


class PinnedVenvTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.environment = self.folder / 'venv'
        official_wheels.venv_python(self.environment).parent.mkdir(parents=True)
        official_wheels.venv_python(self.environment).touch()
        self.log = self.folder / 'pip.log'

    def install(self, *outputs, log=True):
        """Runs `pinned_venv` with pip answering `outputs` in turn, where an
        answer is its output, a failure unless it is `OK`; returns what it did."""
        answers = [subprocess.CompletedProcess([], 0 if output == OK else 1, output)
                   for output in outputs]
        printed = io.StringIO()
        result = None
        with mock.patch.object(subprocess, 'run', side_effect=answers) as run, \
                mock.patch.object(official_wheels.time, 'sleep') as sleep, \
                contextlib.redirect_stdout(printed):
            try:
                result = official_wheels.pinned_venv(
                    self.environment,
                    {'wheel_url': 'https://x/m.whl', 'wheel_sha256': 'ab'},
                    self.log if log else None,
                )
            except subprocess.CalledProcessError as error:
                result = error
        return result, run.call_count, [call.args[0] for call in sleep.call_args_list], printed.getvalue()

    def test_success_needs_no_retry(self):
        result, runs, waits, printed = self.install(OK)
        self.assertEqual(result, official_wheels.venv_python(self.environment).absolute())
        self.assertEqual((runs, waits), (1, []))
        self.assertNotIn('::warning::', printed)
        self.assertEqual(self.log.read_text(encoding='utf-8'), OK)

    def test_the_pinned_digest_stays_in_every_attempt(self):
        with mock.patch.object(subprocess, 'run', side_effect=[
            subprocess.CompletedProcess([], 1, READ_TIMEOUT),
            subprocess.CompletedProcess([], 0, OK),
        ]) as run, mock.patch.object(official_wheels.time, 'sleep'), \
                contextlib.redirect_stdout(io.StringIO()):
            official_wheels.pinned_venv(
                self.environment, {'wheel_url': 'https://x/m.whl', 'wheel_sha256': 'ab'})
        for call in run.call_args_list:
            self.assertEqual(call.args[0][-1], 'https://x/m.whl#sha256=ab')

    def test_network_failures_are_retried_with_a_warning(self):
        for failure in (READ_TIMEOUT, DNS, SERVER_ERRORS, RATE_LIMIT, INDEX_DOWN):
            with self.subTest(failure=failure):
                result, runs, waits, printed = self.install(failure, OK)
                self.assertIsInstance(result, Path)
                self.assertEqual(runs, 2)
                self.assertEqual(waits, [official_wheels.PIP_WAITS[0]])
                self.assertEqual(printed.count('::warning::'), 1)

    def test_the_log_keeps_every_attempt(self):
        self.install(READ_TIMEOUT, DNS, OK)
        self.assertEqual(self.log.read_text(encoding='utf-8'), READ_TIMEOUT + DNS + OK)

    def test_three_network_failures_raise_and_show_the_log(self):
        result, runs, waits, printed = self.install(READ_TIMEOUT, READ_TIMEOUT, READ_TIMEOUT)
        self.assertIsInstance(result, subprocess.CalledProcessError)
        self.assertEqual(runs, 3)
        self.assertEqual(waits, list(official_wheels.PIP_WAITS))
        self.assertEqual(printed.count('::warning::'), 2)
        self.assertIn('Read timed out', printed)
        self.assertIn(str(self.log), printed)

    def test_permanent_failures_raise_at_once_and_show_the_log(self):
        for failure in (HASH_MISMATCH, BAD_VERSION, MISSING, UNSUPPORTED):
            with self.subTest(failure=failure):
                result, runs, waits, printed = self.install(failure)
                self.assertIsInstance(result, subprocess.CalledProcessError)
                self.assertEqual((runs, waits), (1, []))
                self.assertNotIn('::warning::', printed)
                self.assertIn(failure.splitlines()[-1].strip(), printed)

    def test_a_permanent_failure_after_network_trouble_is_not_retried(self):
        for failure in (DNS + HASH_MISMATCH, READ_TIMEOUT + MISSING, RECOVERED + BAD_VERSION,
                        RECOVERED + HASH_MISMATCH):
            with self.subTest(failure=failure):
                _, runs, waits, _ = self.install(failure)
                self.assertEqual((runs, waits), (1, []))

    def test_an_unknown_failure_is_not_retried(self):
        _, runs, _, _ = self.install('ERROR: Could not build wheels for m\n')
        self.assertEqual(runs, 1)

    def test_a_retry_after_a_failure_that_turns_permanent_stops(self):
        result, runs, waits, _ = self.install(READ_TIMEOUT, HASH_MISMATCH)
        self.assertIsInstance(result, subprocess.CalledProcessError)
        self.assertEqual(runs, 2)
        self.assertEqual(waits, [official_wheels.PIP_WAITS[0]])

    def test_the_end_of_a_long_log_is_shown(self):
        lines = [f'line {number}' for number in range(100)] + [HASH_MISMATCH]
        _, _, _, printed = self.install('\n'.join(lines))
        self.assertNotIn('line 0\n', printed)
        self.assertIn('Got        dc90', printed)

    def test_without_a_log_pip_is_shown_as_it_is_and_not_twice(self):
        result, _, _, printed = self.install(HASH_MISMATCH, log=False)
        self.assertIsInstance(result, subprocess.CalledProcessError)
        self.assertEqual(printed.count('DO NOT MATCH THE HASHES'), 1)
        self.assertFalse(self.log.exists())

    def test_what_a_console_cannot_print_does_not_hide_the_failure(self):
        result, _, _, printed = self.install(HASH_MISMATCH + 'caf�\n')
        self.assertIsInstance(result, subprocess.CalledProcessError)
        self.assertIn('caf?', printed)


if __name__ == '__main__':
    unittest.main()

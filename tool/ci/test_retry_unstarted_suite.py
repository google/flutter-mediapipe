"""Unit tests for the one retry rule, and for the scripts that follow it, each run
for real with stand-ins for flutter, adb and xcrun:
python3 -B -m unittest tool/ci/test_retry_unstarted_suite.py"""
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import retry_unstarted_suite as rule  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RULE = ROOT / 'tool/ci/retry_unstarted_suite.py'
LOADING = '00:00 +0: loading /Users/runner/work/flutter-mediapipe/gallery/integration_test/retrieval_test.dart\n'
# Job 115415070813 on iOS.
LOAD_FAILED = (LOADING +
               '00:00 +0 -1: loading /Users/runner/work/flutter-mediapipe/gallery/integration_test/retrieval_test.dart [E]\n'
               '  Failed to load "/Users/runner/work/flutter-mediapipe/gallery/integration_test/retrieval_test.dart": '
               'Connecting to the VM Service timed out.\n'
               '00:00 +0 -1: Some tests failed.\n')
# Job 126763702835's first attempt on Android, which passed on its retry.
NO_DEBUG_CONNECTION = (LOADING +
                       "Running Gradle task 'assembleDebug'...                            306.0s\n"
                       '✓ Built build/app/outputs/flutter-apk/app-debug.apk\n'
                       'No tests ran.\n'
                       'Error waiting for a debug connection: The log reader stopped unexpectedly\n')
A_TEST_PASSED = LOADING + '00:00 +0: first test\n00:05 +1: second test\n'
A_TEST_FAILED = LOADING + '00:00 +0: first test\n00:05 +0 -1: first test [E]\n  Expected: 1\n  Actual: 2\n00:05 +0 -1: second test\n'
PASSED = LOADING + '00:00 +0: first test\n00:05 +1: All tests passed!\n'
# flutter's own status when `timeout` ends it; iOS gets a real SIGALRM instead.
HANG = 'hang'


class NoTestStartedTest(unittest.TestCase):
    def test_runs_that_started_no_test(self):
        for log in (LOADING,
                    LOAD_FAILED,
                    NO_DEBUG_CONNECTION,
                    '00:00 +0: loading test/web/result_test.dart\n',
                    '\x1b[32m00:00 +0\x1b[0m: loading test/web/result_test.dart\n',
                    'Running build hook...00:00 +0: loading test/web/result_test.dart\n',
                    '00:00 +0: loading test/a_test.dart\n00:01 +0: loading test/b_test.dart\n'):
            with self.subTest(log):
                self.assertTrue(rule.no_test_started(log))

    def test_runs_that_started_a_test(self):
        for log in (A_TEST_PASSED,
                    A_TEST_FAILED,
                    PASSED,
                    LOADING + '00:00 +0: first test\n',
                    LOADING + '00:00 +0: test/web/result_test.dart: first test\n',
                    LOADING + '00:03 +0: (setUpAll)\n',
                    LOADING + '00:03 +0 -1: (setUpAll) [E]\n',
                    LOADING + '00:03 +0 ~1: second test\n',
                    LOADING + '00:03 +0 ~1: loading test/b_test.dart\n',
                    LOADING + 'Running build hook...00:00 +0: first test\n',
                    LOADING + '\x1b[32m00:00 +0\x1b[0m: first test\n',
                    LOADING + '00:00 +0: loading a model\n',
                    LOADING + '00:09 +3: loading test/b_test.dart\n',
                    LOADING + '00:09 +0 -1: Some tests failed.\n',
                    LOADING + '00:09 +0: All tests passed!\n',
                    LOAD_FAILED + '00:03 +0 -1: second test\n'):
            with self.subTest(log):
                self.assertFalse(rule.no_test_started(log))

    def test_a_log_with_no_loading_line_is_not_read_as_a_stalled_load(self):
        for log in ('', 'Error: Could not find pubspec.yaml\n', '✅ test/web/result_test.dart: first test\n'):
            with self.subTest(log):
                self.assertFalse(rule.no_test_started(log))


class CommandTest(unittest.TestCase):
    def run_rule(self, log, attempt=1, status=124, suite='sdk_all_test'):
        with tempfile.NamedTemporaryFile('w', suffix='.log', encoding='utf-8') as file:
            file.write(log)
            file.flush()
            return subprocess.run([sys.executable, '-B', str(RULE), '--suite', suite, '--attempt', str(attempt),
                                   '--status', str(status), '--log', file.name], capture_output=True, text=True)

    def test_a_retry_warns_with_the_suite_the_attempt_and_the_cause(self):
        for log, status, cause in ((LOADING, 124, 'stalled past its limit (exit 124)'),
                                   (LOADING, 142, 'stalled past its limit (exit 142)'),
                                   (LOADING, 1, 'exit 1'),
                                   (LOAD_FAILED, 1, 'Connecting to the VM Service timed out. (exit 1)'),
                                   (NO_DEBUG_CONNECTION, 124, 'The log reader stopped unexpectedly (exit 124)')):
            with self.subTest(cause):
                result = self.run_rule(log, status=status)
                self.assertEqual(result.returncode, 0)
                self.assertRegex(result.stdout, r'^::warning title=Retried sdk_all_test::sdk_all_test attempt 1 of 2: '
                                 r'no test started, .*' + re.escape(cause) + r'\. Running it once more\.\n$')

    def test_only_the_first_attempt_retries(self):
        result = self.run_rule(LOADING, attempt=2)
        self.assertEqual((result.returncode, result.stdout), (1, ''))

    def test_a_started_test_does_not_retry_or_warn(self):
        for log in A_TEST_PASSED, A_TEST_FAILED:
            result = self.run_rule(log)
            self.assertEqual((result.returncode, result.stdout), (1, ''))

    def test_a_pass_does_not_retry(self):
        self.assertEqual(self.run_rule(LOADING, status=0).returncode, 1)

    def test_a_missing_log_does_not_retry(self):
        result = subprocess.run([sys.executable, '-B', str(RULE), '--suite', 'a', '--attempt', '1',
                                 '--status', '124', '--log', '/nonexistent/attempt.log'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')

    def test_the_warning_stays_on_one_line_and_escapes_commands(self):
        result = self.run_rule(LOADING + 'Failed to load "a%0Ab": 100%\n', status=1, suite='audio tests: a, b')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.count('\n'), 1)
        self.assertIn('title=Retried audio tests%3A a%2C b::audio tests: a, b attempt', result.stdout)
        self.assertIn('a%250Ab": 100%25', result.stdout)


class ScriptTest(unittest.TestCase):
    """The real scripts and the real rule. A plan gives what each flutter test
    invocation prints and how it ends; anything past the plan passes."""

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.tree = Path(temp.name) / 'repository'
        self.stub = Path(temp.name) / 'stub'
        (self.tree / 'gallery/tool').mkdir(parents=True)
        (self.tree / 'gallery/assets').mkdir()
        (self.tree / 'gallery/assets/manifest.json').write_text(json.dumps({'tasks': []}))
        (self.tree / 'tool/ci').mkdir(parents=True)
        (self.tree / 'packages/web').mkdir(parents=True)
        self.stub.mkdir()
        shutil.copy(RULE, self.tree / 'tool/ci')
        for script in 'test_android_sdk_tasks.sh', 'test_ios_simulator_suite.sh', 'test_chrome_suite.sh':
            shutil.copy(ROOT / 'gallery/tool' / script, self.tree / 'gallery/tool')
        self.write_stub('flutter', 'n=$(( $(cat "$STUB/count" 2>/dev/null || echo 0) + 1 ))\n'
                                   'echo "$n" > "$STUB/count"\n'
                                   'echo "$*" >> "$STUB/invocations"\n'
                                   'if [ -f "$STUB/$n.out" ]; then cat "$STUB/$n.out"; else echo "00:01 +1: All tests passed!"; fi\n'
                                   'status=$(cat "$STUB/$n.status" 2>/dev/null || echo 0)\n'
                                   'if [ "$status" = alarm ]; then kill -ALRM $$; sleep 30; fi\n'
                                   'exit "$status"\n')
        self.write_stub('timeout', 'shift 2\nexec "$@"\n')
        self.write_stub('adb', 'case "$*" in *get-state*) cat "$STUB/adb-state";; esac\n')
        self.write_stub('xcrun', 'echo "$*" >> "$STUB/reboots"\n')
        (self.stub / 'adb-state').write_text('device\n')

    def write_stub(self, name, body):
        path = self.stub / name
        path.write_text('#!/bin/sh\n' + body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC)

    def plan(self, steps, hang):
        for number, (output, status) in enumerate(steps, 1):
            (self.stub / f'{number}.out').write_text(output, encoding='utf-8')
            (self.stub / f'{number}.status').write_text(str(hang if status == HANG else status))

    def run_script(self, arguments, cwd):
        env = {**os.environ, 'STUB': str(self.stub), 'PATH': f'{self.stub}{os.pathsep}{os.environ["PATH"]}'}
        env.pop('GITHUB_ACTIONS', None)
        return subprocess.run(['bash', *arguments], cwd=cwd, env=env, capture_output=True, text=True, timeout=120)

    def attempts(self, name):
        invocations = (self.stub / 'invocations').read_text().splitlines()
        return sum(name in line for line in invocations)

    def ios(self, steps):
        self.plan(steps, 'alarm')
        return self.run_script(['tool/test_ios_simulator_suite.sh', 'SIM', '900', 'retrieval_test'],
                               self.tree / 'gallery'), self.attempts('retrieval_test')

    def android(self, steps):
        self.plan(steps, 124)
        return self.run_script([str(self.tree / 'gallery/tool/test_android_sdk_tasks.sh'), 'emulator-5554'],
                               self.tree), self.attempts('sdk_all_test')

    def chrome(self, steps):
        self.plan(steps, 124)
        return self.run_script(['../../gallery/tool/test_chrome_suite.sh', 'vision browser tests', 'test/web'],
                               self.tree / 'packages/web'), self.attempts('chrome')

    # name, plan, flutter test attempts, whether it stays red, warnings.
    CASES = (
        ('no test line then a hang', [(LOADING, HANG), (PASSED, 0)], 2, False, 1),
        ('a load that failed', [(LOAD_FAILED, 1), (PASSED, 0)], 2, False, 1),
        ('no debug connection', [(NO_DEBUG_CONNECTION, HANG), (PASSED, 0)], 2, False, 1),
        ('a test passed then a hang', [(A_TEST_PASSED, HANG), (PASSED, 0)], 1, True, 0),
        ('a test failed then a hang', [(A_TEST_FAILED, HANG), (PASSED, 0)], 1, True, 0),
        ('a test failed', [(A_TEST_FAILED, 1), (PASSED, 0)], 1, True, 0),
        ('a hang on the retry', [(LOADING, HANG), (LOADING, HANG), (PASSED, 0)], 2, True, 1),
        ('a failure on the retry', [(LOADING, HANG), (A_TEST_FAILED, 1), (PASSED, 0)], 2, True, 1),
        ('a pass', [(PASSED, 0)], 1, False, 0),
    )

    def check(self, run):
        for name, steps, attempts, red, warnings in self.CASES:
            with self.subTest(name):
                for path in self.stub.iterdir():
                    if path.name not in ('flutter', 'timeout', 'adb', 'xcrun', 'adb-state'):
                        path.unlink()
                result, seen = run(steps)
                self.assertEqual(seen, attempts, result.stdout)
                self.assertEqual(result.returncode != 0, red, result.stdout + result.stderr)
                self.assertEqual(result.stdout.count('::warning'), warnings, result.stdout)
                # What a retried run printed is still in the step's log.
                self.assertEqual(result.stdout.count('loading /Users'),
                                 sum(step[0].count('loading /Users') for step in steps[:attempts]))
                if warnings:
                    self.assertRegex(result.stdout, r'attempt 1 of 2: no test started, .*Running it once more')

    def test_ios(self):
        self.check(self.ios)

    def test_android(self):
        self.check(self.android)

    def test_chrome(self):
        self.check(self.chrome)

    def test_ios_stays_red_with_the_status_of_its_last_attempt(self):
        result, _ = self.ios([(A_TEST_FAILED, HANG)])
        self.assertEqual(result.returncode, 142)

    def test_ios_reboots_the_simulator_only_for_a_retry(self):
        self.ios([(A_TEST_FAILED, HANG)])
        self.assertFalse((self.stub / 'reboots').exists())
        (self.stub / 'count').unlink()
        (self.stub / 'invocations').unlink()
        self.ios([(LOADING, HANG), (PASSED, 0)])
        self.assertEqual((self.stub / 'reboots').read_text().splitlines(),
                         ['simctl shutdown SIM', 'simctl boot SIM', 'simctl bootstatus SIM -b'])

    def test_a_failed_suite_never_exits_green(self):
        for run in self.ios, self.chrome:
            with self.subTest(run.__name__):
                result, _ = run([(A_TEST_FAILED, 3)])
                self.assertEqual(result.returncode, 3)
                (self.stub / 'count').unlink()
                result, _ = run([(LOADING, 3), (A_TEST_FAILED, 3)])
                self.assertEqual(result.returncode, 3)
                (self.stub / 'count').unlink()

    def test_ios_keeps_every_attempt_in_the_artifact_and_reads_only_the_last(self):
        # The first file passed; its test lines must not count against the second.
        self.plan([(PASSED, 0), (LOADING, HANG), (PASSED, 0)], 'alarm')
        gallery = self.tree / 'gallery'
        self.assertEqual(self.run_script(['tool/test_ios_simulator_suite.sh', 'SIM', '900', 'one'], gallery).returncode, 0)
        result = self.run_script(['tool/test_ios_simulator_suite.sh', 'SIM', '900', 'two'], gallery)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.attempts('two'), 2)
        self.assertEqual((gallery / 'sdk-ios-simulator.log').read_text(encoding='utf-8').count('All tests passed!'), 2)

    def test_android_does_not_retry_on_an_emulator_that_is_gone(self):
        (self.stub / 'adb-state').write_text('offline\n')
        result, attempts = self.android([(LOADING, HANG), (PASSED, 0)])
        self.assertEqual((result.returncode, attempts), (1, 1), result.stdout)
        self.assertNotIn('::warning', result.stdout)

    def test_android_keeps_its_verdict_check_on_a_started_run(self):
        result, attempts = self.android([(A_TEST_PASSED, 0), (PASSED, 0)])
        self.assertEqual((result.returncode, attempts), (1, 1), result.stdout)
        self.assertIn("exited 0 without reporting 'All tests passed!'", result.stdout)

    def test_every_script_asks_for_the_reporter_the_rule_reads(self):
        for run in self.ios, self.android, self.chrome:
            with self.subTest(run.__name__):
                (self.stub / 'invocations').unlink(missing_ok=True)
                run([(PASSED, 0)])
                invocations = (self.stub / 'invocations').read_text().splitlines()
                self.assertTrue(invocations)
                for line in invocations:
                    self.assertIn('--reporter expanded', line)

    def test_chrome_is_not_held_open_by_a_process_left_behind(self):
        self.write_stub('flutter', 'echo "$*" >> "$STUB/invocations"\necho "00:01 +1: All tests passed!"\nsleep 30 &\nexit 0\n')
        started = time.monotonic()
        self.assertEqual(self.chrome([])[0].returncode, 0)
        self.assertLess(time.monotonic() - started, 20)


if __name__ == '__main__':
    unittest.main()

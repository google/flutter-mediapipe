"""Decides whether a failed `flutter test --reporter expanded` run runs again.

One rule for the iOS, Android and browser suites: a run gets one retry only if
no test had started, meaning no test line followed flutter_test's `loading`
line. Such a run stalled or failed to load, so it reached no verdict. Once any
test has started, a failure or a stall is the result and stays red, so a retry
can never turn a failed test green. A log this cannot read as a run that never
started stays red too.

A retry prints a workflow warning naming the suite, the attempt and the cause.

Usage, after a failed attempt, with that attempt's log alone; exit 0 means run
the suite once more:
  python3 -B tool/ci/retry_unstarted_suite.py --suite sdk_all_test \\
    --attempt 1 --status 124 --log attempt.log
"""
import argparse
import re
import sys

ATTEMPTS = 2
# Exit statuses of a run its limit ended: `timeout`, `timeout --kill-after`
# and the alarm that bounds a run on macOS, which has no `timeout`.
STALLED = (124, 137, 142)
ANSI = re.compile(r'\x1b\[[0-9;]*[A-Za-z]')
# flutter_test's progress line, anywhere in the line: a spinner can come first
# ("Running build hook...00:00 +0: a test").
PROGRESS = re.compile(r'\d+:\d\d \+(\d+)(?: ~(\d+))?(?: -(\d+))?: (.*)')
LOADING = re.compile(r'loading \S+\.dart( \[E\])?\s*$')
# What the tool prints for a run that never reached a test.
NO_START = re.compile(r'Failed to load .*|Failed to start Dart Development Service.*|'
                      r'Error waiting for a debug connection.*')


def no_test_started(log):
    """Whether `log` shows `loading` and nothing that only a started test prints."""
    loaded = load_failed = False
    for line in log.splitlines():
        match = PROGRESS.search(ANSI.sub('', line))
        if not match:
            continue
        passed, skipped, failed, description = match.groups()
        if passed != '0' or skipped:
            return False
        loading = LOADING.match(description)
        if loading:
            loaded = True
            load_failed = load_failed or bool(loading.group(1))
        elif not (load_failed and failed and description.strip() == 'Some tests failed.'):
            return False
    return loaded


def cause(log, status):
    match = NO_START.search(ANSI.sub('', log))
    if match:
        return f'{match.group().strip()[:200]} (exit {status})'
    if status in STALLED:
        return f'stalled past its limit (exit {status})'
    return f'exit {status}'


def escape(text):
    return text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--suite', required=True)
    parser.add_argument('--attempt', type=int, required=True)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('--log', required=True)
    args = parser.parse_args()
    with open(args.log, encoding='utf-8', errors='replace') as log:
        text = log.read()
    if args.attempt >= ATTEMPTS or args.status == 0 or not no_test_started(text):
        return 1
    title = escape(args.suite).replace(':', '%3A').replace(',', '%2C')
    print(f'::warning title=Retried {title}::{escape(args.suite)} attempt {args.attempt} of '
          f'{ATTEMPTS}: no test started, {escape(cause(text, args.status))}. Running it once more.',
          flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())

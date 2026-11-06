#!/usr/bin/env bash
# Runs `flutter test --platform chrome` in the current directory. Chrome
# sometimes never connects to flutter test on a hosted runner, which then waits
# out the job's limit (28 minutes in the fork's job 107265900608, September 23,
# 2026), and the suites take seconds. So a run has five minutes, and one that
# started no test goes once more (tool/ci/retry_unstarted_suite.py). Once a test
# has started, a failure or a stall stays red.
set -euo pipefail
suite=${1:?usage: test_chrome_suite.sh <suite name> [flutter test arguments]}
shift
rule="$(cd "$(dirname "$0")/../.." && pwd)/tool/ci/retry_unstarted_suite.py"
log=$(mktemp)
for attempt in 1 2; do
  status=0
  # To a file, not a pipe: a Chrome left behind must not hold the step open.
  timeout --kill-after=30 300 flutter test --platform chrome "$@" \
    --reporter expanded > "$log" 2>&1 || status=$?
  cat "$log"
  [ "$status" = 0 ] && exit 0
  python3 -B "$rule" --suite "$suite" --attempt "$attempt" --status "$status" \
    --log "$log" || exit "$status"
done

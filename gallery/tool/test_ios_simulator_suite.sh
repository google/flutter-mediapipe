#!/usr/bin/env bash
# Runs one integration test file on a booted iOS simulator, under a limit in
# seconds. A hosted simulator sometimes stalls while loading the app and never
# starts the tests, so a run that started no test goes once more on a rebooted
# simulator (tool/ci/retry_unstarted_suite.py). Once a test has started, a
# failure or a stall stays red.
set -euo pipefail
device=${1:?usage: test_ios_simulator_suite.sh <device> <limit> <test> [flutter test flags]}
limit=${2:?usage: test_ios_simulator_suite.sh <device> <limit> <test> [flutter test flags]}
test=${3:?usage: test_ios_simulator_suite.sh <device> <limit> <test> [flutter test flags]}
shift 3
cd "$(dirname "$0")/.."
for attempt in 1 2; do
  status=0
  log=$(mktemp)
  perl -e 'alarm shift; exec @ARGV' "$limit" flutter test -d "$device" \
    "integration_test/$test.dart" "$@" --reporter expanded 2>&1 |
    tee -a sdk-ios-simulator.log "$log" || status=$?
  [ "$status" = 0 ] && exit 0
  python3 -B ../tool/ci/retry_unstarted_suite.py --suite "$test" \
    --attempt "$attempt" --status "$status" --log "$log" || exit "$status"
  xcrun simctl shutdown "$device" || true
  xcrun simctl boot "$device"
  xcrun simctl bootstatus "$device" -b
done

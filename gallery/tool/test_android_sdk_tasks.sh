#!/usr/bin/env bash
# Runs the official Android SDK task tests on an emulator, CPU only: Face and
# Hand Landmarker; Pose, Gesture and Holistic; Face and Object Detector and
# Image Classifier; Image Embedder; Image Segmenter; the text and audio tasks;
# Decision Maker, the retrieval tasks and the speech tasks; then every live
# tile and the gallery journey through the sidebar. They run as
# sdk_all_test.dart, one app launch as on Test Lab: each extra install and
# launch was another chance for a hosted emulator to lose its Dart Development
# Service or die outright.
#
# The emulator's SwiftShader GL accepts a GPU task, then TFLite's GL delegate
# fails on the first frame, so GPU stays a phone check. `flutter test`
# installs the app itself, so camera permission is granted while it runs;
# otherwise the live demo waits behind the permission prompt and gets no
# frames. Firebase Test Lab grants it the same way before launch.
set -euo pipefail
device=${1:?usage: test_android_sdk_tasks.sh <device>}
cd "$(dirname "$0")/.."
(
  while true; do
    adb -s "$device" shell pm grant com.example.mediapipe_gallery \
      android.permission.CAMERA >/dev/null 2>&1 || true
    sleep 1
  done
) &
granter=$!
trap 'kill $granter 2>/dev/null || true' EXIT
log=$(mktemp)
# Runs one suite under a limit in seconds. It passes only on exit 0 and
# flutter_test's own "All tests passed!", as tool/ci/run_release_suite.py asks
# of a release run. `timeout` exits 124 on a stall even if flutter test handles
# the signal and exits 0, so a killed suite never passes.
run_suite() {
  local limit=$1 rc=0
  shift
  timeout --kill-after=30 "$limit" flutter test -d "$device" "$@" \
      --reporter expanded 2>&1 | tee "$log" || rc=$?
  # 137: it outlasted the signal, and --kill-after ended it.
  [ "$rc" != 137 ] || rc=124
  if [ "$rc" = 124 ]; then
    echo "$1 stalled past $limit s; the emulator's log follows"
    adb -s "$device" logcat -d -t 300 || true
  elif [ "$rc" = 0 ] && ! grep -q 'All tests passed!' "$log"; then
    echo "::error::$1 exited 0 without reporting 'All tests passed!'"
    rc=1
  fi
  return "$rc"
}
for attempt in 1 2; do
  # The suites take about 11 minutes with the Gradle build, the gallery
  # journey's Proofreader and Summarizer pages included, and Decision Maker,
  # the retrieval tasks and the speech tasks add their downloads (678 MB,
  # 388 MB, and 615 MB and 87 MB) and a few minutes of emulated inference. On hosted emulators flutter test sometimes
  # installs the app and then hears nothing more, so a run still going at 30
  # minutes has stalled.
  status=0
  run_suite 1800 integration_test/sdk_all_test.dart --dart-define=SDK_GPU=skip || status=$?
  [ "$status" = 0 ] && break
  # A run that started no test reached no verdict, so the suites run once more
  # (tool/ci/retry_unstarted_suite.py). Once a test has started, a failure or a
  # stall stays red, and an emulator that is gone cannot pass a second run.
  if [ "$(adb -s "$device" get-state 2>/dev/null)" = device ] &&
      python3 -B ../tool/ci/retry_unstarted_suite.py --suite sdk_all_test \
        --attempt "$attempt" --status "$status" --log "$log"; then
    continue
  fi
  exit 1
done
run_suite 300 integration_test/face_landmarker_still_image_test.dart
# EmbeddingGemma, Proofreader and Summarizer, when the build bundles them: a
# launch of their own, since the generative models take minutes to answer on
# an emulated CPU. The outcome lands in a file for the coverage rows, so a
# failure here fails only their cells.
mkdir -p ../build/coverage-outcomes
if python3 -c "import json, sys; sys.exit(0 if 'text_proofreader' in json.load(open('assets/manifest.json'))['tasks'] else 1)"; then
  status=0
  run_suite 1800 integration_test/sdk_modern_text_test.dart || status=$?
  if [ "$status" = 0 ]; then echo success > ../build/coverage-outcomes/android-modern-text
  else echo failure > ../build/coverage-outcomes/android-modern-text; exit 1; fi
else
  echo skipped > ../build/coverage-outcomes/android-modern-text
fi

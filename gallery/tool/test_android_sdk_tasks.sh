#!/usr/bin/env bash
# Runs the official Android SDK task tests on an emulator, CPU only: Face and
# Hand Landmarker; Pose, Gesture and Holistic; Face and Object Detector and
# Image Classifier; Image Embedder; Image Segmenter; the text and audio tasks;
# Decision Maker and the retrieval tasks; then every live tile and the gallery
# journey through the sidebar. They run as
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
for attempt in 1 2; do
  # The suites take about 11 minutes with the Gradle build, the gallery
  # journey's Proofreader and Summarizer pages included, and Decision Maker
  # and the retrieval tasks add their downloads (678 MB and 388 MB) and a few
  # minutes of emulated inference. On hosted emulators flutter test sometimes
  # installs the app and then hears nothing more, so a run still going at 30
  # minutes has stalled.
  status=0
  timeout 1800 flutter test -d "$device" integration_test/sdk_all_test.dart \
      --dart-define=SDK_GPU=skip --reporter expanded 2>&1 | tee "$log" || status=$?
  [ "$status" = 0 ] && break
  if [ "$status" = 124 ]; then
    echo "sdk_all_test stalled; the emulator's log follows"
    adb -s "$device" logcat -d -t 300 || true
  fi
  # A stall, or a Dart Development Service that never started, means no test
  # ran to a verdict, so the suites run once more.
  if [ "$attempt" = 1 ] && { [ "$status" = 124 ] ||
      grep -q "Failed to start Dart Development Service" "$log"; }; then
    echo "Retrying sdk_all_test"
    continue
  fi
  exit 1
done
timeout 300 flutter test -d "$device" \
  integration_test/face_landmarker_still_image_test.dart \
  --reporter expanded
# EmbeddingGemma, Proofreader and Summarizer, when the build bundles them: a
# launch of their own, since the generative models take minutes to answer on
# an emulated CPU. The outcome lands in a file for the coverage rows, so a
# failure here fails only their cells.
mkdir -p ../build/coverage-outcomes
if python3 -c "import json, sys; sys.exit(0 if 'text_proofreader' in json.load(open('assets/manifest.json'))['tasks'] else 1)"; then
  status=0
  timeout 1800 flutter test -d "$device" integration_test/sdk_modern_text_test.dart \
      --reporter expanded || status=$?
  if [ "$status" = 0 ]; then echo success > ../build/coverage-outcomes/android-modern-text
  else echo failure > ../build/coverage-outcomes/android-modern-text; exit 1; fi
else
  echo skipped > ../build/coverage-outcomes/android-modern-text
fi

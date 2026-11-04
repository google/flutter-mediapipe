The Android face tests reuse `flutter_litert`'s Flutter instrumentation runner,
arm64 APK configuration, Firebase project (`flutter-litert`) and physical Pixel 7
device (`panther`, Android API 33). No Firebase SDK or Firebase initialization is
needed in the application.

The gallery runs the face tasks on Google's MediaPipe vision library
(`libmediapipe_tasks_vision.so`), which the vision package's hook bundles.
Until Google publishes it, prepare with `--asset-source` (see the
[gallery README](../README.md)).

Prepare and build from the repository root:

```sh
dart run tool/gallery_builder/bin/prepare_gallery.dart --target android/arm64 --tasks face_landmarker
cd gallery
flutter pub get
flutter build apk --config-only --debug --target integration_test/sdk_face_landmarker_test.dart --target-platform android-arm64
cd android
./gradlew app:assembleAndroidTest -Pmediapipe.testLabAbi=arm64-v8a
./gradlew app:assembleDebug -Ptarget="$(pwd)/../integration_test/sdk_face_landmarker_test.dart" -Ptarget-platform=android-arm64 -Pmediapipe.testLabAbi=arm64-v8a
```

Run Gradle commands sequentially. Before uploading, inspect the APK ZIP and
verify `lib/arm64-v8a/libflutter.so`, `libmediapipe_tasks_vision.so` and the
bundled face model exist. A successful Gradle exit alone does not prove correct APK
packaging. The runner grants camera permission before launching the activity.

From the repository root, submit one physical-device execution:

```sh
gcloud firebase test android models describe panther --project flutter-litert
gcloud firebase test android run --project flutter-litert --type instrumentation \
  --app gallery/build/app/outputs/apk/debug/app-debug.apk \
  --test gallery/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
  --device model=panther,version=33,locale=en,orientation=portrait \
  --timeout 8m --results-history-name mediapipe-face-landmarker-android
```

Keep cloud submission manual and use one device without sharding or automatic
retries: all CPU/GPU checks share that execution, conserving the five daily runs.
Use the results bucket URL from gcloud to download `logcat`,
`instrumentation.results` and `test_result_1.xml`. Structured diagnostic lines
start with `SDK_FACE_LANDMARKER`.

The manual `android-face-testlab.yml` workflow runs a larger bundle,
`integration_test/sdk_all_test.dart`: these face checks plus every other
official SDK suite (hand, Pose, Gesture, Holistic, detection, classification,
embedding, both segmenters), on CPU and GPU, then the text and audio tasks,
EmbeddingGemma, Proofreader and Summarizer on the CPU, and the live tiles. The
Pixel 8a and Galaxy S24 also run Decision Maker, Universal Embedder and
Semantic Retriever on the CPU (21 tasks, 18 bundled models): the phone
downloads Decision Maker's Laya (678 MB) and the retrieval tasks' EmbeddingGemma
2 (388 MB) on first use. The Galaxy A12 (4 GB) runs the other 18, which took it
29 minutes; each run gets 45, the most Test Lab allows on a physical device.
Choose the
physical device and API level when dispatching; `gpu: required` fails a GPU
refusal instead of recording it. The job saves the tagged measurement lines
from logcat as `measurements.log`. It uses the same
`FIREBASE_TEST_LAB_CREDENTIALS` secret name as `flutter_litert`. GitHub secrets
are scoped to a repository: the credential must already be available in this
repository before dispatching that workflow. Local gcloud runs use the existing
Google Cloud login. No credentials are copied into source files.

Coverage:

- Known face: 478 finite landmarks on CPU and GPU, 52 blendshapes, matrix layout,
  file/model-buffer loading, RGB/RGBA/BGRA padded rows, and copied output lifetime.
- VIDEO: monotonic timestamps, queued frames, repeated face frames, blank frames,
  recovery, mode/rotation validation, CPU → GPU → CPU recreation, and disposal.
- Rotated face pixels: all four sensor orientations with SDK rotation correction.
- Physical camera: twenty processed frames for each CPU → GPU → CPU stage and
  switching cameras where available, including GPU on the second camera.

A device in a rack may see no face. Camera success proves capture, conversion,
rotation submission, task execution and lifecycle; the bundled face proves
nonempty inference. It does not prove visual overlay alignment on a person,
portrait/landscape UI alignment, release performance, or broad device support.
The APK is debug because Flutter's `integration_test` runner requires it.

Official references: [Flutter tests in Test Lab](https://firebase.google.com/docs/test-lab/flutter/integration-testing-with-flutter)
and [Android FaceLandmarker](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/android).

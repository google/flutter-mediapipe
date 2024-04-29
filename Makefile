# Runs the utility to pull in all header files from `google/mediapipe`
headers:
	cd tool/builder && dart bin/main.dart headers

# Downloads all necessary task models
models:
	cd tool/builder && dart bin/main.dart model -m textclassification
	cd tool/builder && dart bin/main.dart model -m textembedding
	cd tool/builder && dart bin/main.dart model -m languagedetection


# Runs `ffigen` for all packages
generate: generate_core generate_text

# Runs `ffigen` for all packages and runs all tests
test: generate_core test_core generate_text test_text

# Runs all tests for all packages
test_only: test_core test_text

# Rebuilds the MediaPipe task for macOS
# Assumes google/mediapipe and google/flutter-mediapipe are siblings on the file system
compile_text_classifier_macos_arm:
	cd ../mediapipe && bazel build --linkopt -s --config darwin_arm64 --strip always --define MEDIAPIPE_DISABLE_GPU=1 mediapipe/tasks/c/text/text_classifier:libtext_classifier.dylib
	cd ../mediapipe && sudo cp bazel-bin/mediapipe/tasks/c/text/text_classifier/libtext_classifier.dylib ../flutter-mediapipe/packages/mediapipe-task-text/example/assets/libtext_classifier_arm64.dylib

compile_text_classifier_macos_x86:
	cd ../mediapipe && bazel build --linkopt -s --config darwin_x86_64 --strip always --define MEDIAPIPE_DISABLE_GPU=1 mediapipe/tasks/c/text/text_classifier:libtext_classifier.dylib
	cd ../mediapipe && sudo cp bazel-bin/mediapipe/tasks/c/text/text_classifier/libtext_classifier.dylib ../flutter-mediapipe/packages/mediapipe-task-text/example/assets/libtext_classifier_x64.dylib

# Runs `sdks_finder` to update manifest files
sdks:
	dart tool/builder/bin/main.dart sdks

analyze:
	cd packages/mediapipe-core && dart format -o write .
	cd packages/mediapipe-task-text && dart format -o write .

# Core ---

# Runs `ffigen` for `mediapipe_core`
generate_core:
	cd packages/mediapipe-core && dart run ffigen --config=ffigen.yaml

# Runs unit tests for `mediapipe_core`
test_core:
	cd packages/mediapipe-core && dart test

# Text ---

# Runs `ffigen` for `mediapipe_text`
generate_text:
	cd packages/mediapipe-task-text && dart --enable-experiment=native-assets run ffigen --config=ffigen.yaml

# Runs all text tests
test_text:
	cd packages/mediapipe-task-text && flutter test
	cd packages/mediapipe-task-text/example && flutter test

example_text:
	cd packages/mediapipe-task-text/example && flutter run -d macos

# Inference ---
generate_inference:
	cd packages/mediapipe-task-inference && dart --enable-experiment=native-assets run ffigen --config=ffigen.yaml

# Example genai invocation.
# Note that `GEMMA_4B_CPU_URI` can either be a local path or web URL. Similar values exist for
# 8B and GPU variants.
#
# For desktop development, standard environment variables like this work great.
# $ GEMMA_4B_CPU_URI=/path/to/gemma-2b-it-cpu-int4.bin flutter run -d [macos, windows, linux]
# For emulator or attached device testing, use `--dart-define` for the same values.
# $ flutter run -d [<device_id>] --dart-define=GEMMA_4B_CPU_URI=https://url/to.com/gemma-2b-it-cpu-int4.bin

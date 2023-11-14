# Runs the utility to pull in all header files from `google/mediapipe`
headers:
	cd tool/builder && dart bin/main.dart headers

# Runs `ffigen` for all packages
generate: generate_core generate_text

# Runs `ffigen` for all packages and runs all tests
test: generate_text test_text generate_core test_core

# Runs all tests for all packages
test_only: test_core test_text

# Rebuilds the MediaPipe task for macOS
# Assumes google/mediapipe and google/flutter-mediapipe are siblings on the file system
compile_text_classifier_macos:
	cd ../mediapipe && bazel build --linkopt -s --config darwin_arm64 --strip always --define MEDIAPIPE_DISABLE_GPU=1 mediapipe/tasks/c/text/text_classifier:libtext_classifier.dylib
	cd ../mediapipe && sudo cp bazel-bin/mediapipe/tasks/c/text/text_classifier/libtext_classifier.dylib ../flutter-mediapipe/packages/mediapipe-task-text/example/assets

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

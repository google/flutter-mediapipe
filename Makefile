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

# Runs `sdks_finder` to update manifest files
sdks:
	dart tool/builder/bin/main.dart sdks

analyze:
	cd packages/mediapipe-core && dart format -o write .
	cd packages/mediapipe-task-text && dart format -o write .
	cd packages/mediapipe-task-genai && dart format -o write .

# Core ---

get_core:
	cd packages/mediapipe-core && dart pub get

# Runs `ffigen` for `mediapipe_core`
generate_core:
	cd packages/mediapipe-core && dart run ffigen --config=ffigen.yaml

# Runs unit tests for `mediapipe_core`
test_core:
	cd packages/mediapipe-core && dart test

core: get_core generate_core test_core

# Text ---

# Runs `ffigen` for `mediapipe_text`
generate_text:
	cd packages/mediapipe-task-text && dart --enable-experiment=native-assets run ffigen --config=ffigen.yaml

# Runs all text tests

get_text:
	cd packages/mediapipe-task-text && dart pub get
	cd packages/mediapipe-task-text/example && flutter pub get

test_text:
	cd packages/mediapipe-task-text && dart --enable-experiment=native-assets test
	cd packages/mediapipe-task-text/example && flutter test

example_text:
	cd packages/mediapipe-task-text/example && flutter run -d macos

text: get_text generate_text test_text

# GenAI ---
generate_genai:
	cd packages/mediapipe-task-genai && dart --enable-experiment=native-assets run ffigen --config=ffigen.yaml

# Example genai invocation.
# Note that `GEMMA_4B_CPU_URI` can either be a local path or web URL. Similar values exist for
# 8B and GPU variants.
#
# For desktop development, standard environment variables like this work great.
# $ GEMMA_4B_CPU_URI=/path/to/gemma-2b-it-cpu-int4.bin flutter run -d [macos, windows, linux]
# For emulator or attached device testing, use `--dart-define` for the same values.
# $ flutter run -d [<device_id>] --dart-define=GEMMA_4B_CPU_URI=https://url/to.com/gemma-2b-it-cpu-int4.bin

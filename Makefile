# Runs unit tests for `mediapipe_core`
test_core:
	cd packages/mediapipe-core && dart test

# Runs the utility to pull in all header files from `google/mediapipe`
headers:
	cd packages/build_cmd && dart bin/main.dart headers

# Runs `ffigen` for `mediapipe_core`
generate_core:
	cd packages/mediapipe-core && dart run ffigen --config=ffigen.yaml

# Runs `ffigen` for `mediapipe_text`
generate_text:
	cd packages/mediapipe-task-text && dart run ffigen --config=ffigen.yaml

# Runs `ffigen` for all packages
generate: generate_core generate_text

# Compiles the faked C artifacts for testing
compile_fake_text:
	# Builds standalone executable
	cd packages/mediapipe-task-text/test/c && gcc fake_text_classifier.c -o fake_text_classifier
	# Builds what Flutter needs
	cd packages/mediapipe-task-text/test/c && gcc -static -c -fPIC *.c -o fake_text_classifier.o
	cd packages/mediapipe-task-text/test/c && gcc -shared -o fake_text_classifier.dylib fake_text_classifier.o 

# Runs all text tests
test_text_only:
	cd packages/mediapipe-task-text && flutter test

# Runs `ffigen` for `mediapipe_text` and all text tests
test_text: compile_fake_text test_text_only

# Runs `ffigen` for all packages, compiles the faked C artifacts, and runs all tests
test: generate_text test_text generate_core test_core

# Runs `ffigen` for all packages and all tests for all packages
test_only: test_core test_text


SHELL := /bin/bash
# Every task family, found on disk: packages/mediapipe-task-<family>. Each
# has a models_<family> and a test_<family> target.
TASK_FAMILIES := $(sort $(patsubst packages/mediapipe-task-%,%,$(wildcard packages/mediapipe-task-*)))
# Families whose models download only with `make models_all`: Decision's Laya
# (678 MB) and Retrieval's EmbeddingGemma 2 (388 MB). Their reference tests
# skip without them; CI caches and runs them (decision.yaml, retrieval.yaml).
LARGE_MODEL_FAMILIES := decision retrieval
DART_PACKAGES := packages/mediapipe-core tool/task_benchmarks
FLUTTER_PACKAGES := $(addprefix packages/mediapipe-task-,$(TASK_FAMILIES))
ALL_PACKAGES := $(DART_PACKAGES) $(FLUTTER_PACKAGES)
# The gallery's pubspec is generated per target by tool/gallery_builder, so
# it is format-checked without package resolution
# and analyzed by the platform workflows after preparation.
GALLERY_SOURCES := lib test integration_test tool
# The generated pubspec (sdk ^3.12.0) may be absent when formatting, and
# unresolved files default to the newest language version, whose style differs.
GALLERY_FORMAT := dart format --language-version=3.12
ANALYZE_PACKAGES := $(ALL_PACKAGES)

.PHONY: get models models_all analyze format check_format generate check_text_abi generate_text generate_vision test test_only test_core test_text test_vision test_vision_flutter ci

get:
	@for package in $(DART_PACKAGES); do (cd "$$package" && dart pub get) || exit $$?; done
	@for package in $(FLUTTER_PACKAGES); do (cd "$$package" && flutter pub get) || exit $$?; done

# Download versioned test/example models; no model is embedded in a package.
# Every family's but the LARGE_MODEL_FAMILIES', which `models_all` adds.
models:
	@for target in $(addprefix models_,$(filter-out $(LARGE_MODEL_FAMILIES),$(TASK_FAMILIES))) \
	    models_embedding models_proofreader models_summarizer; do \
	  $(MAKE) $$target || exit $$?; \
	done

models_all: models
	@for family in $(LARGE_MODEL_FAMILIES); do $(MAKE) models_$$family || exit $$?; done

.PHONY: models_vision
models_vision:
	cd packages/mediapipe-task-vision && dart tool/download_models.dart

analyze:
	@for package in $(ANALYZE_PACKAGES); do (cd "$$package" && dart analyze --fatal-infos) || exit $$?; done

format:
	@for package in $(ALL_PACKAGES); do (cd "$$package" && dart format .) || exit $$?; done
	@cd gallery && $(GALLERY_FORMAT) $(GALLERY_SOURCES)

check_format:
	@for package in $(ALL_PACKAGES); do (cd "$$package" && dart format --output=none --set-exit-if-changed .) || exit $$?; done
	@cd gallery && $(GALLERY_FORMAT) --output=none --set-exit-if-changed $(GALLERY_SOURCES)

# Regenerate against the checked-in headers, never a floating upstream checkout.
generate:
	$(MAKE) check_text_abi
	$(MAKE) generate_text
	$(MAKE) generate_vision

# The classic text bindings are adapted from Google's wheel's ctypes
# definitions; the retired 2024 headers must not regenerate them, so this
# checks them instead.
check_text_abi:
	cd packages/mediapipe-task-text && dart test test/classic_text_abi_test.dart --reporter expanded

# The Proofreader and Summarizer, from Google's headers.
generate_text:
	cd packages/mediapipe-task-text && dart ../mediapipe-core/tool/generate_bindings.dart

generate_vision:
	cd packages/mediapipe-task-vision && dart ../mediapipe-core/tool/generate_bindings.dart

test:
	$(MAKE) models
	$(MAKE) test_only

# Every package's suite. Decision's and Retrieval's reference tests skip
# unless `make models_all` downloaded their models. Each suite gets 180 s a
# test, as in CI: a task's close waits for Google's usage-logging upload, and
# a slow reply holds a test past the default 30 s (upstream-issues.md UP-025).
test_only:
	@for package in core $(TASK_FAMILIES); do $(MAKE) test_$$package || exit $$?; done

test_core:
	cd packages/mediapipe-core && dart test --timeout 180s --reporter expanded

test_text:
	cd packages/mediapipe-task-text && dart test --timeout 180s --reporter expanded

.PHONY: test_audio models_audio test_audio_stream_bridge test_audio_web
models_audio:
	cd packages/mediapipe-task-audio && dart tool/download_models.dart

test_audio:
	$(MAKE) test_audio_stream_bridge
	cd packages/mediapipe-task-audio && dart test --timeout 180s --reporter expanded

# The audio stream's callback-copy bridge, its slots and their threads,
# under AddressSanitizer.
test_audio_stream_bridge:
	mkdir -p build/ci-tmp
	clang -Wall -Wextra -Werror -g -fsanitize=address -pthread packages/mediapipe-task-audio/native/audio_stream_bridge.c packages/mediapipe-task-audio/native/audio_stream_bridge_test.c -o build/ci-tmp/audio_stream_bridge_test
	build/ci-tmp/audio_stream_bridge_test

# The emulated stream and the decoders in Chrome, compiled to JavaScript and
# to WebAssembly. A contributor shortcut: CI runs these commands itself.
test_audio_web:
	cd packages/mediapipe-task-audio && flutter test --platform chrome test/web --reporter expanded
	cd packages/mediapipe-task-audio && flutter test --platform chrome --wasm test/web --reporter expanded

# The C ABI sizes the vision bindings assume, against the vendored headers.
test_vision:
	clang++ -std=c++17 -fsyntax-only -Wall -Wextra -Werror -I packages/mediapipe-core/native/include packages/mediapipe-task-vision/tool/abi_check.cc
	cd packages/mediapipe-task-vision && dart test --timeout 180s --reporter expanded --exclude-tags isolated
	cd packages/mediapipe-task-vision && dart test --timeout 180s --reporter expanded --tags isolated

# A contributor shortcut: CI runs this command itself.
.PHONY: test_vision_web
test_vision_web:
	cd packages/mediapipe-task-vision && flutter test --platform chrome test/web --reporter expanded

test_vision_flutter:
	cd packages/mediapipe-task-vision && python3 tool/test_flutter_macos.py

.PHONY: models_text
models_text:
	cd packages/mediapipe-task-text && dart tool/download_models.dart

.PHONY: models_embedding test_embedding_macos
models_embedding:
	cd packages/mediapipe-task-text && dart tool/download_models.dart embedding_gemma

# A contributor shortcut: CI runs the script itself.
test_embedding_macos:
	cd packages/mediapipe-task-text && python3 -B tool/test_embedding_macos.py

# EmbeddingGemma, Proofreader and Summarizer against Google's wheel for this
# host, as the Linux and Windows CI runners test them (they run the script
# itself; this is a contributor shortcut).
.PHONY: test_modern_text
test_modern_text:
	python3 -B tool/test_modern_text.py

.PHONY: test_modern_task_matrix
test_modern_task_matrix:
	cd tool/task_benchmarks && dart pub get
	cd packages/mediapipe-task-text && dart tool/download_models.dart embedding_gemma proofreader summarizer
	cd packages/mediapipe-task-vision && dart tool/download_models.dart interactive_segmenter
	python3 -B tool/task_benchmarks/run_macos.py

.PHONY: models_proofreader test_text_stream_bridge
models_proofreader:
	cd packages/mediapipe-task-text && dart tool/download_models.dart proofreader

test_text_stream_bridge:
	clang++ -std=c++17 -fsyntax-only -Wall -Wextra -Werror -I packages/mediapipe-core/native/include packages/mediapipe-task-text/tool/abi_check.cc
	mkdir -p build/ci-tmp
	clang -Wall -Wextra -Werror -g -fsanitize=address -pthread packages/mediapipe-task-text/native/text_stream_bridge.c packages/mediapipe-task-text/native/text_stream_bridge_test.c -o build/ci-tmp/text_stream_bridge_test
	build/ci-tmp/text_stream_bridge_test

.PHONY: models_summarizer
models_summarizer:
	cd packages/mediapipe-task-text && dart tool/download_models.dart summarizer

# Run sequentially even when make is invoked with -j.
ci:
	$(MAKE) get
	$(MAKE) models
	$(MAKE) analyze
	$(MAKE) check_format
	$(MAKE) test_only
	$(MAKE) test_vision_flutter

# Decision Maker's Laya model (678 MB) and its native suite against Google's
# Python answers, on Google's decision library for this host.
.PHONY: models_decision test_decision
models_decision:
	cd packages/mediapipe-task-decision && dart tool/download_models.dart

test_decision:
	cd packages/mediapipe-task-decision && dart test --timeout 180s --reporter expanded

# The retrieval tasks' EmbeddingGemma 2 model (388 MB) and their native suite
# against Google's Python answers, on Google's retrieval library for this host.
.PHONY: models_retrieval test_retrieval
models_retrieval:
	cd packages/mediapipe-task-retrieval && dart tool/download_models.dart

test_retrieval:
	cd packages/mediapipe-task-retrieval && dart test --timeout 180s --reporter expanded

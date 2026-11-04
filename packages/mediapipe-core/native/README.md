# MediaPipe C API headers

`include/` holds Google's MediaPipe Tasks C API headers, unmodified, as
Google ships them with the per-family libraries the hooks bundle
(`lib/src/native_assets/family_runtimes.dart`). `BUILD_INFO` names the build
they come from: MediaPipe 1.2.0, Google's nightly of 2026-10-18. They are licensed under
Apache 2.0 like the rest of this repository.

Google ships one header tree per family. `include/` merges the five; a header
that several families ship is byte-identical in each. Includes are relative to
`include/` (`core/base_options.h`, `vision/face_detector/face_detector.h`),
and `mediapipe_tasks_<family>.h`, which Google generates without a license
header, includes a family's whole API.

`tool/generate_bindings.dart` generates a family's bindings from them with
the family's `ffigen.yaml`: the vision package's, and the text package's
Proofreader and Summarizer. Each of those packages' `tool/abi_check.cc` checks
the struct sizes its bindings assume. The other bindings are written by hand
and match these headers. The headers are not published, and no hook compiles
against them.

To update, replace `include/` and `BUILD_INFO` with the headers of the build
the hooks pin, merging the families' trees, then run `make generate`,
`make test_vision` and `make test_text_stream_bridge`. For another nightly,
`tool/pin_nightly.py` moves them with the pins, and stops if the C API changed
beyond comments.

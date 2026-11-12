# Official EmbeddingGemma reference

`official_reference.json` contains outputs from Google's 1.1.0 release candidate wheel (`mediapipe-nightly` 1.1.0rc20260925 for macOS arm64, core's `referenceWheels`), unmodified, with the
CPU delegate and the version 1 EmbeddingGemma 300M task. Moving from 1.0.1 to
1.0.0 earlier changed float values by at most 0.007, with the same ctypes
ABI.
The JSON records the exact native-library/model SHA-256 digests and ctypes ABI.
Prompts are passed as `TextFormatContext` to Google, not formatted by this repo.
All input sentences were written for this test; no external text corpus is used.

Regenerate with `tool/generate_embedding_gemma_reference.py` using the wheel
pinned in mediapipe-core's `tool/official_wheels.py` (`MACOS`, read from
`referenceWheels`). The script
checks its version, architecture and native checksum before inference.
Do not replace these references with Dart-generated outputs.

The comparing test is `test/embedding_gemma_test.dart`. All six text tasks run
on Google's text library; fresh-consumer tests also verify simultaneous use.

The model is downloaded separately by `dart tool/download_models.dart embedding_gemma`;
it is not committed. Its terms are Google's
[Gemma Terms](https://ai.google.dev/gemma/terms).

The recorded layouts are the reference wheel's. Google's 1.2.3 libraries, which
the package loads, added `npu_dispatch_library_dir` to the base options, so
every field after them moved by 8 bytes; the tests take those structs from
`test/support/modern_text_reference.dart` (`referenceAbi`), as 1.2.3's ctypes
declare them.

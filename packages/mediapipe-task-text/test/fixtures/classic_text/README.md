# Official MediaPipe text references

`official_reference.json` records the unmodified macOS arm64 CPU outputs of
Google's 1.1.0 release candidate wheel (`mediapipe-nightly` 1.1.0rc20260925 for macOS arm64, core's `referenceWheels`) for the version-1 BERT
classifier, Universal Sentence Encoder and language detector. Model SHA-256 pins also appear in `lib/models.dart`; the reference
generator checks both those models and the original Google library digest.

There are 26 model/option cases, four rejected option configurations, four
cosine comparisons and three repeated-request sequences. Classifier timestamps
advance by 1000 ms per request; the tests preserve these native values.
Floating outputs are compared within 1e-6 and quantized bytes exactly. Local
native outputs match exactly; the measured 1.11e-16 difference is in cosine math.

Hosted macOS 15 runners differ from the macOS 26 physical-Mac baseline: both
the package and fresh Flutter consumer first differed in USE greeting vector
element 4 by `1.2814998626708984e-6`. CI therefore generates an independent
reference using the checksum-pinned official wheel for each test runner
(core's `referenceWheels`).
The `1e-6` tolerance and exact quantized-byte comparisons remain unchanged.

Run `tool/prepare_classic_text_reference.py` after downloading the three models,
then set `MEDIAPIPE_CLASSIC_TEXT_REFERENCE_DIR` to its absolute output directory
(`build/classic-text-reference` at the repository root by default). The package
suite and fresh-app test both require a receipt matching the official library,
wheel, model and baseline hashes. Missing or modified outputs fail. Without an
override, local tests continue using the checked-in baseline. The generator
records host differences and refuses structural changes; CI uploads the
reference, receipt and official Python log for review. Python is used only to
prepare expected outputs; it remains blocked inside consumer builds.

Regenerate using `tool/generate_classic_text_reference.py` in an environment
holding this host's pinned official wheel (`official_wheels.py` in
mediapipe-core's `tool/`), or pass `--python-package-root` for an extracted one.
Moving macOS from 1.0.1 to 1.0.0 changed 838 values by at most 3.2e-6 and
nothing structural. `--output` writes elsewhere
without replacing the reviewed fixture. Do not generate expected values
from the Dart implementation. Test sentences were written for this fixture.

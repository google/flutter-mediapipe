# Official MediaPipe text references

`official_reference.json` records the unmodified macOS arm64 CPU outputs of
Google's 1.2.3 wheel (`mediapipe` 1.2.3 for macOS arm64, core's
`releaseReferenceWheels`) for the version-1 BERT classifier, Universal Sentence
Encoder and language detector. Moving from Google's 1.1.0 wheel to 1.2.2 changed
only the language detections: 1.2.2 drops every language below about 0.3,
and the classifier and remaining language values
are bit-identical. Moving from 1.2.2 to 1.2.3 changed no classifier or language
value; the embedder's agree within 2.4e-7, as separate generating runs of one
build do, inside the tests' 1e-6, and the options structs grew by the 8 bytes of
the base options' NPU dispatch folder. 1.2.3's Python names the detections
`languages`; the generator keeps the fixture's `detections`. Model SHA-256 pins also appear in `lib/models.dart`; the reference
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
(core's `releaseReferenceWheels`).
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

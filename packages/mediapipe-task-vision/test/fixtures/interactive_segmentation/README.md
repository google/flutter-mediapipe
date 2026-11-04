# Interactive Segmenter references

`cats_and_dogs.jpg` is the unchanged sample image used by Google's
[official notebook](https://github.com/google-ai-edge/mediapipe-samples/blob/main/examples/interactive_segmentation/python/interactive_segmenter.ipynb),
downloaded from `https://storage.googleapis.com/mediapipe-assets/cats_and_dogs.jpg`.
Its URL and SHA-256 are recorded in `official_reference.json`.

The raw RGB input is the official JPEG decode sampled at every fourth row and
column, cropped to 299 columns. It intentionally has an odd width for padding
tests. Reference masks are little-endian float32, losslessly gzip-compressed.
The report records uncompressed hashes, dimensions, exact complete stroke
histories and native/API/model provenance. The models are never modified.

Regenerate with `tool/generate_interactive_segmenter_reference.py` using a
Python environment containing Google's 1.1.0 release candidate wheel (`mediapipe-nightly` 1.1.0rc20260925 for macOS arm64, core's `referenceWheels`). The generator refuses a different
native library or model hash.
It can also import an extracted wheel using `--python-package-root`.

Coverage includes file and raw inputs, repeated requests, partial strokes,
multiple positive strokes, negative strokes, lasso, undo by resubmitting a
shorter history, RGBA, blank input and image replacement. Three cases show
how Google's graph reads strokes: a lasso is the bounding box of its points
(the open outline and the two opposite corners give `raw-lasso`'s mask), and
an unfinished Exclude stroke reads as the finished one (`raw-negative`'s).
Six cases send strokes as the gallery's editor does: an Exclude drag down
the dog, finished and in progress (one mask, since Google reads both the
same); a lasso before the pointer lifts, the one case where the completed
flag changes the mask; and a lasso with an Exclude drag, two lassos, and an
Include, a lasso and an Exclude drag together. The generator asserts that
each of these strokes changes the mask, so a wrapper that dropped or misread
one could not still match. Cases with the same mask share one file. The
`summaries` section reduces three Exclude and Lasso histories on the whole
photo to a 16 x 8 grid of cell means, the mean and the foreground share, for
the gallery's phone tests; those masks are not stored. The Exclude summary's
drag removes most of the dog, and the generator asserts that dropping it
moves the grid by more than 0.05, against the phones' 0.02. The blank image
produces a nonempty mask with this official model; references preserve that
behavior. Timings here are observations from reference generation, not warmed
Flutter performance benchmarks.

An empty stroke list fails inside Google's decoder graph and leaves it in an
error state until the image is reset. The Dart API must reject this input before
native calls. GPU initialization in the official macOS wheel fails because the
stroke calculator requests GLSL 330 in its OpenGL 2.1 context. CPU is the only
qualified backend for this runtime; do not silently fall back from GPU.

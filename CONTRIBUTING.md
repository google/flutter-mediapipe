# Contributing to MediaPipe Tasks for Flutter

## Contributor License Agreements

We'd love to accept your patches! Before we can take them, we have to jump a couple of legal hurdles.

Please fill out either the individual or corporate Contributor License Agreement (CLA).

  * If you are an individual writing original source code and you're sure you own the intellectual property, then you'll need to sign an [individual CLA](https://code.google.com/legal/individual-cla-v1.0.html).
  * If you work for a company that wants to allow you to contribute your work, then you'll need to sign a [corporate CLA](https://code.google.com/legal/corporate-cla-v1.0.html).

Follow either of the two links above to access the appropriate CLA and instructions for how to sign and return it. Once we receive it, we'll be able to accept your pull requests.

***NOTE***: Only original source code from you and other people that have signed the CLA can be accepted into the main repository.

## Contributing code

MediaPipe team members will be assigned to review your pull requests. Once the
pull requests are approved and pass continuous integration checks, we will
merge them.

Open issues and pull requests in this repository. Describe the problem, the
resulting behavior, and relevant validation. Keep runtime updates and new task
implementations separate from mechanical package renames where practical.

Retain existing copyright and license notices. Include the appropriate license
notice in new source files and follow the surrounding Dart or native code style.
Run the checks relevant to the affected package and document any native SDK or
device requirements that prevent validation.

See [README.md](README.md) for the current development scope.

## Before opening a pull request

From the repository root, run what applies to your change:

```sh
make analyze                   # dart analyze, every package and example
make check_format
make test                      # downloads the test models, runs every package's tests
python3 -B tool/check_docs.py  # README samples compile (web too), links resolve
python3 -B tool/check_repository.py  # family lists and shared pins agree
python3 -B packages/mediapipe-core/tool/publish_check.py   # pub dry run
python3 -B tool/check_archives.py    # an app builds from the archives' files
python3 -B packages/mediapipe-core/tool/test_bundled_models.py
```

`make test` leaves out Decision's and Retrieval's models (678 MB and 388 MB),
so their reference tests skip; run `make models_all` first to include them.
CI runs them with cached models.

The last two build fresh apps from the packages as pub.dev would ship them.
`check_archives.py` stages exactly the files the pub dry run lists and builds
an app that imports every family, for this desktop and the web by default
(name targets to build others: `macos linux windows web android ios`); CI
builds all six. `test_bundled_models.py` bundles one model per family with
`dart run mediapipe_core:bundle_models` and runs them offline. CI runs the
rest (Android emulator, Linux, Windows and three browsers).

CI also runs the gallery's device suites in release builds, which `flutter
test` and `flutter drive` cannot: `tool/ci/run_release_suite.py` builds a
suite as the release app, launches it and reads flutter_test's report from its
output. After preparing the gallery, run one locally with, for example,
`python3 -B tool/ci/run_release_suite.py --target macos --suite
integration_test/gallery_journey_test.dart`. In a device suite, check a
widget's own properties rather than the semantics tree: `find.bySemanticsLabel`
reads `RenderObject.debugSemantics`, which release builds leave empty.

One browser path CI does not reach: the gallery journey in WebKit. On
GitHub's macOS runners WebKit's page process sometimes ends mid-journey with
no error, and on `macos-15` it has no WebGPU at all, so CI runs only
WebKit's API and text and audio checks. After a change to the gallery, to
Decision Maker or the retrieval tasks, or to Google's browser runtimes, and
before a release, run the gallery journey in WebKit on a Mac with Apple
silicon. Build the release gallery as `.github/workflows/web.yaml`
does, start `python3 -B gallery/tool/web_server.py`, then run:

```sh
node gallery/tool/browser/test_gallery_journey.mjs --browser=webkit
node gallery/tool/browser/test_gallery_journey.mjs --browser=webkit \
  --tasks=decision_maker,universal_embedder,semantic_retriever
```

The second run expects Decision Maker to answer on Laya, and Hungry Fish and both
retrieval tasks to be cards with their reason
([UP-054](upstream-issues.md#up-054-in-webkit-the-browser-runtime-embeds-every-input-as-zeros-with-embeddinggemma-2)).

## Versions and the first release

The first release is 0.1.0 of `mediapipe_core`, `mediapipe_vision`,
`mediapipe_text`, `mediapipe_audio`, `mediapipe_decision` and
`mediapipe_retrieval`, published together.

On pub.dev, `mediapipe_core` and `mediapipe_text` (and the removed
`mediapipe_genai`) are Google's 0.0.1 previews from May 2024, published from
[google/flutter-mediapipe](https://github.com/google/flutter-mediapipe).
Only their uploaders can publish new versions of these names, and the next
version must be above 0.0.1. Under Dart's rules for versions before 1.0, the minor version
marks a breaking change, so 0.1.0 is the version that follows Google's
previews. `mediapipe_vision`, `mediapipe_audio`, `mediapipe_decision` and
`mediapipe_retrieval` were free names on October 9, 2026, kept at 0.1.0 so
all six release together.

Until 0.1.0 is on pub.dev:

- Every package stays at `version: 0.1.0`, however much changes.
- Each CHANGELOG has one section, `## 0.1.0`, describing the package as it
  ships. Edit that section; do not add version sections, and do not call a
  change breaking or list what it renamed, since no release came before it.
- `MIGRATION.md` covers only Google's published 0.0.1 API. Changes between
  unpublished states never need a migration note.

The pubspecs are publishable as checked in: no `publish_to: none`, and each
family depends on `mediapipe_core: ^0.1.0`, as its published copy must. A
checked-in `pubspec_overrides.yaml` beside each family pubspec (and in the
sample, the benchmarks and every generated consumer app) points
`mediapipe_core` at the sibling package instead, so a checkout builds against
itself; pub leaves that file out of the published archive. Before publishing,
run `publish_check.py`, `check_archives.py` and the bundled-model check
above, then publish
`mediapipe_core` first and the five families after it, never with `--force`.

## How to add a task

A task is only complete when it runs Google's official pipeline on every
platform it claims, and a test proves the output matches Google's.

1. **Pin the model.** Add Google's model URL and SHA-256 to the family's
   `lib/models.dart` (`XxxModels.name`), and its snake_case name to
   `XxxModels.byName` so apps can bundle it. `mirror_runtime_assets.py` picks
   it up; give it a license there if it is not Apache-2.0.
2. **Native platforms.** Bind Google's C API with the family's `ffigen` config
   and wrap it in `lib/src/io/`: create, run and close on a worker isolate,
   copying results into the shared value types from `mediapipe_core`
   (`MediaPipeCategory`, `Classifications`, `Landmark` and so on). The same
   bindings serve Android, iOS, macOS, Linux and Windows: each family's hook
   bundles Google's C library for that family there. Pass a model path
   through core's `nativeModelPath`, since Google's Android resolver reads a
   relative path as an APK asset.
3. **Web.** Add it to the family's `assets/worker.js`, using Google's bundle,
   and to the Dart web backend, which hands the worker's JSON to the family's
   one decoder (`lib/src/results/decoders.dart` in vision and text,
   `lib/src/decoders.dart` in audio).
4. **Capabilities.** Declare where it runs and why not elsewhere in the
   family's `lib/src/capabilities.dart`: `queryXxxCapabilities()` and a pure
   `xxxCapabilitiesForPlatform(TaskPlatform)`. For vision, also add it to
   `visionRuntimeTasks` in `vision_tasks.dart` and to
   `tool/VISION_TASKS_STATUS.md` in the same commit.
5. **Public API.** One class for every platform. `XxxOptions` extends core's
   `TaskOptions` (`model`, `modelPath`, `modelBytes`, `delegate`) with
   Google's settings and defaults; `static Future<Xxx> create(XxxOptions)`
   refuses a delegate the capability query rules out (core's
   `requireDelegate`); Google's verb (`detect`, `classify`, `embed` and so
   on); an immutable `XxxResult` on the shared value types; a `delegate`
   getter; an idempotent `Future<void> dispose()`; failures as
   `TaskException`, errors through the returned `Future`. Export it from the
   family's main library and run `tool/api_parity`
   (`dart run bin/api_parity.dart --update`) so the snapshots show the new
   API; the check requires it to be identical on native and web.
6. **Tests.** Generate a reference with Google's own Python for the pinned
   runtime version, check it in as a fixture, and compare every value in unit
   tests; add the task to the browser suite's comparison with Google's
   JavaScript, to the CI coverage rows (`tool/coverage/`), and to its
   family's `test/coverage_matrix_test.dart`, which checks the matrix row
   against the task's capability claims. A task whose
   output differs between Google's releases (the generative text tasks) is
   compared with the wheel of each platform's own version, generated on the
   runner (`packages/mediapipe-task-text/tool/prepare_modern_text_reference.py`).
7. **Docs.** The family README's task table, the CHANGELOG, and any platform
   limit with its upstream issue in `upstream-issues.md`.

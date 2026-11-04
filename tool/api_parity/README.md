# API parity

Checks every public library (`lib/*.dart`) of every package under
`packages/`, found from their pubspecs:

- **Snapshots.** `snapshots/<family>/<library>.txt` is the library's API
  dump, so every change to what the packages publish shows up in review.
  A `<library>.web.txt` exists only while the web API differs. A family's
  app-facing library (`mediapipe_<family>.dart`) re-exports core's, so its
  snapshot starts with `include package:mediapipe_core/mediapipe_core.dart`
  and lists only the family's own declarations; the check fails if the
  family stops re-exporting any of core's unchanged.
- **Parity.** For each app-facing library, the analyzer resolves it twice,
  once with the native compilers' `dart.library.io`, `ffi` and `isolate`,
  once with the web compilers' `js_interop`, `js_util`, `html` and `js`, and
  diffs every public symbol and member. The two must be identical.
- **Conventions.** In the app-facing libraries: no platform type
  (`dart:ffi`, `dart:io`, `dart:js_interop`, `package:web`, ...) in a public
  signature; every task (a class with `static Future<Self> create`) has
  `Future<void> dispose()`, a `delegate` getter and a
  `query<Task>Capabilities()` function; every `*Options` class but
  `TaskOptions` and Gesture Recognizer's `ClassifierOptions` extends
  `TaskOptions`; no public name collides with `dart:core`, `dart:async`,
  `dart:typed_data`, `dart:collection`, `dart:math` or Flutter's foundation,
  services, widgets, material and cupertino libraries.

`baseline.txt` lists the findings the API still has. The check fails on a
finding that is not in the baseline, on a baseline entry that no longer
holds, and on a snapshot that is missing, differs or names no library, so the
baseline only shrinks deliberately.

```sh
cd tool/api_parity && dart pub get
dart run bin/api_parity.dart            # check
dart run bin/api_parity.dart --update   # rewrite baseline.txt and snapshots/
```

Every package needs `flutter pub get` first; the tool reads their package
configurations.

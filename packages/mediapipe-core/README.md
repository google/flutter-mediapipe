# mediapipe_core

The shared layer of the MediaPipe task packages (`mediapipe_vision`,
`mediapipe_text`, `mediapipe_audio`); apps normally get it through them rather
than depending on it directly. It owns everything the
task families share, so each of vision, text and audio works alone and an app
using several loads one copy of each shared piece. That includes the code that
downloads and verifies Google's MediaPipe libraries, which each family's build
hook uses to bundle its own:

| Platform | Runtime |
| --- | --- |
| Android 9+ (arm64-v8a, x86_64; armeabi-v7a on the CPU, without the large models), iOS 15+ (device, arm64 simulator), macOS 14+ arm64, Linux x64, Windows x64 | Google's MediaPipe 1.2.0 C library for each family (`MediaPipeTasksVisionC`, `libmediapipe_tasks_text`, and so on), bundled by that family's hook |
| Web | Google's JavaScript runtime, through each family's web plugin |

An app ships only the libraries of the families it depends on, and needs no
setting to get them. The hooks download them from a pre-release of
`hugocornellier/mediapipe_flutter_native`, where Google's development builds
are posted unmodified until Google publishes them, and check every file's
SHA-256 and size (`lib/src/native_assets/family_runtimes.dart`).
`hooks.user_defines.mediapipe_core.asset_source` can point at a directory
holding them, named by SHA-256, instead.

## What every family shares

Each family's library (`package:mediapipe_vision/mediapipe_vision.dart`,
`mediapipe_text` and `mediapipe_audio`) re-exports
`package:mediapipe_core/mediapipe_core.dart`, so these types are the same
on every platform and in every family:

- `TaskOptions`, the base of every options class: exactly one of `model` (a
  pinned `DownloadAsset`), `modelPath` and `modelBytes`, plus `delegate`
  (`Delegate.cpu` or `Delegate.gpu`).
- The value types results are made of, named after Google's containers:
  `MediaPipeCategory`, `Classifications`, `Embedding`, `Detection`,
  `BoundingBox`, `NormalizedKeypoint`, `NormalizedLandmark`, `Landmark`,
  `Matrix`, `ConfidenceMask` and `CategoryMask`.
- `MediaPipeException` and its subtypes: `RuntimeUnavailableException` (with a
  `fix`), `ModelDownloadException` and `TaskException` (Google's runtime
  refused a call; `statusCode`, `gpuUnavailable`).
- `TaskCapabilities` and `TaskPlatform`, which every task's
  `queryXxxCapabilities()` returns; `ModelStore` and `ModelSource`; and
  `MediaPipeWebRuntime`.

`package:mediapipe_core/platform_interface.dart` holds what family packages
and platform plugins need and apps do not.

## Verified downloads and offline builds

Every native runtime and model pin names a primary URL, optional published
mirrors, and one SHA-256. Core tries URLs in order and checks the digest before
publishing a file. It reports every failed location when none matches. Each
native library's primary URL names its file inside Google's nightly archive,
which core reads with HTTP range requests, and its mirror is a copy in a
GitHub pre-release. Model pins name no mirrors.

Each request gets three attempts on a connection error, a timeout or HTTP
408, 429, 500, 502, 503 or 504, waiting a random backoff or the host's
`Retry-After` (at most 30 seconds), and a dropped download resumes where it
stopped. Any other failure, including a digest mismatch, moves to the next
URL at once.

For offline or mirrored builds, point every download at a local directory or
an internal HTTP(S) root holding files named by their full SHA-256. That
source is then used exclusively: the digest check still applies, and a
missing or wrong file fails the build rather than falling back to the
internet.

- Build hooks read it from the app's pubspec (a relative directory resolves
  against that pubspec):

  ```yaml
  hooks:
    user_defines:
      mediapipe_core:
        asset_source: third_party/mediapipe-assets
  ```

  Hooks cannot use an environment variable here: Dart's hook runner passes
  them only an allowlist of variables.
- `ModelStore(source: ...)` takes the same kind of source at run time.
- Command-line tools (`dart run`) read the `MEDIAPIPE_ASSET_SOURCE`
  environment variable.

From a checkout of this repository, fill such a directory for the build
targets you need. Models are included for every target, since apps may use
any family:

```sh
python3 -B packages/mediapipe-core/tool/mirror_runtime_assets.py \
  --target macos/arm64 --target ios/arm64 --prefill /path/to/mediapipe-assets
```

The same tool without `--prefill` is a dry run inventory. It lists each pin,
its target, license information when known, and a proposed GitHub release
asset name. It never uploads anything. The prefill path uses core's verified
downloader. Copy the resulting SHA-named directory to the build machine, or
serve it from an internal URL root.

## Bundled models

Apps bundle the models they use at build time. Each family's `XxxModels.byName`
names its models. The app lists the ones it needs per family in its pubspec,
declares `assets/mediapipe/` under `flutter: assets:`, and runs from its root:

```sh
dart run mediapipe_core:bundle_models
```

The command downloads each listed model (from `asset_source` when it is set),
checks it against its pinned SHA-256, and writes it into `assets/mediapipe/`,
named by that SHA-256 with a readable `manifest.json` beside it. Models that
are no longer listed are removed. With `--check` it changes nothing and fails
when the folder does not match the lists, for CI. It reads each family's
models by running a small generated program,
`.dart_tool/mediapipe_core/bundle_models_registry.dart`, with the app's
packages, since core cannot depend on the families.

A task created with `model:` then looks for its model in this order:

1. the store's cache;
2. the app's bundled copy, copied into the cache once on native platforms,
   where MediaPipe takes a file path;
3. a download, only when `ModelStore.allowDownloads` is true.

Otherwise `create` throws a `RuntimeUnavailableException` whose `fix` names
the pubspec entry to add. `ModelStore().find(model)` performs the same lookup
without ever using the network.

## On-demand models

Downloading at run time is opt-in. Set `ModelStore.allowDownloads = true`
before creating tasks to let `model:` download what the app does not bundle;
calling `get` or `prefetch` directly always may download.

`ModelStore` and `DownloadAsset` come with every family's library. A family
model pin can be passed directly to `get` or `prefetch`; `clear` removes the
store's entries. `get` and `find` return a `ModelSource`: on native platforms
its `path` is a file in application support, which can be given to the task
options as `modelPath`. Each model keeps its original file name. Downloads go to an adjacent
temporary file under a per-model lock shared across isolates and processes,
and cached bytes are checked again on every read. iOS excludes this model folder
from iCloud backup. On web `get` returns verified bytes from Cache Storage
or the app's bundle, and otherwise downloads them. An invalid cached
response is discarded.
Core uses Flutter's `path_provider` for application support rather than
asking every family to supply a directory, so the storage policy stays shared.

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> prepareModels() async {
  final store = ModelStore();
  await store.prefetch(TextModels.bertClassifier);
  final source = await store.get(TextModels.bertClassifier);
  print(source.path); // A file on native platforms; `bytes` in browsers.
}
```

Downloading needs Android's `INTERNET` permission, and a sandboxed macOS app
needs `com.apple.security.network.client`. Bundled models and already
verified cache entries work without network access.

## Web runtime

Browsers load Google's pinned MediaPipe JavaScript and WASM runtime for each
task family (vision, text, audio) from jsDelivr. One setting moves all of them.
For offline use or a strict Content Security Policy, copy the verified
runtimes of the families your app uses into its `web/` folder, from the app
root:

```sh
dart run mediapipe_core:web_runtime web/mediapipe
```

The tool downloads each family's pinned npm archive, checks its integrity and
each listed file's SHA-384, and writes only the files the browser loads.
Workers verify those same file digests from any configured root before
loading the bundle and WASM through Blob URLs. Then, before creating the
first task:

```dart
import 'package:mediapipe_core/mediapipe_core.dart';

void useSelfHostedRuntime() {
  MediaPipeWebRuntime.baseUrl = 'mediapipe/';
}
```

`baseUrl` is an npm-style root, so another npm CDN such as
`https://unpkg.com/` works as well. Each family's library exports the same
class, and it does nothing off the web.
Serve the files with CORS and CSP rules appropriate to your origin.

## Issues and feedback

Please file issues, bugs, or feature requests in our [issue tracker](https://github.com/google/flutter-mediapipe/issues/new).

Issues that are specific to Flutter can be filed in the [Flutter issue tracker](https://github.com/flutter/flutter/issues/new).

To contribute a change to this plugin,
please review our [contribution guide](https://github.com/google/flutter-mediapipe/blob/main/CONTRIBUTING.md)
and open a [pull request](https://github.com/google/flutter-mediapipe/pulls).

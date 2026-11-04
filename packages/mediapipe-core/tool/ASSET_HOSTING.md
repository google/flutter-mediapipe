# Asset hosting

Native downloads are done; browsers are not started. Build hooks now read
Google's per-family libraries from Google's own bucket, fall back to this
project's mirror release, and retry and resume every download. A browser
still loads Google's runtime from one CDN with one `fetch` per file, and
models still have one host each. Found on 2026-10-15, on `main` at
`ed23dcb`, after a jsDelivr outage failed three CI jobs on PR #88; refreshed
on 2026-10-22 against `main` at `acd337f`. Paths are from the repository
root. Check a finding again before building on it.

## Goal

No single host's outage breaks an app, a build or a CI run:

1. **Browsers load Google's runtime from the app's own origin.** Each family
   package ships the files its worker loads, and other hosts are only
   fallbacks. Not started.
2. **Every pin can have fallback hosts.** Each host must serve the pinned
   bytes, which are checked before use, so adding a host never weakens
   anything. Done for the native libraries; models and browser runtimes
   still have one host.
3. **Every download retries.** A few attempts per host, only for transient
   failures, with exponential backoff and jitter, resuming partial native
   downloads, then the next host. Done for native downloads; browsers still
   make one attempt.
4. **Google's official hosting fits in when it exists.** Done for the native
   libraries: Google's bucket is their primary host and this project's
   release their fallback. Google's bucket holds no browser runtimes.

## What happened

On 2026-10-15 jsDelivr's cache misses failed: after 54 to 91 s they returned
502 or 503 with `x-cache: MISS`, `cf-cache-status: BYPASS` and no
`Access-Control-Allow-Origin`, so browsers reported only "Failed to fetch".
Files already in jsDelivr's cache still loaded. On PR #88 that failed:

- the Firefox journey: HTTP 503 for
  `@mediapipe/tasks-audio@1.0.1/wasm/audio_wasm_module_internal.wasm`;
- the Chromium text and audio run, which saw no audio runtime request;
- Retrieval web on Chromium (macos-15), twice: `TaskException: Error: Failed
  to fetch`;
- the coverage gate, which then lacked `universal_embedder` and
  `semantic_retriever` on web/gpu.

During the outage unpkg served the same retrieval WASM with the pinned
SHA-384. Reruns passed after jsDelivr recovered around 14:25 UTC. CI already
self-hosts the runtime for its direct comparisons with Google's JavaScript and
for one text and audio run (`web.yaml`, `dart run mediapipe_core:web_runtime`),
but the gallery's own tasks load from jsDelivr, as any app's do by default.

## Done since 2026-10-15

- **Google's bucket, then a mirror, for the native libraries** (#89,
  2026-10-19). `packages/mediapipe-core/lib/src/native_assets/family_runtimes.dart`:
  each `FamilyRuntime.asset` is the member of Google's archive
  (`familyRuntimeArchiveUrl`,
  `storage.googleapis.com/mediapipe-assets/prebuilts/mediapipe_tasks_c/20261018/mediapipe_tasks_c_20261018.zip`),
  read with range requests, then the same file in this project's
  pre-release `per-family-v1.2.0-nightly.20261018` of
  `hugocornellier/mediapipe_flutter_native` (`familyRuntimeBaseUrl`, posted
  2026-10-19), named `<sha256>-<file>`.
- **Retries, backoff and resume for every native download** (#89).
  `packages/mediapipe-core/lib/src/verified_download.dart`: each request gets
  up to 3 attempts on a connection error, a timeout or HTTP 408, 429, 500,
  502, 503 or 504; the wait is full jitter up to `min(30 s, 1 s × 2^attempt)`,
  or `Retry-After`'s seconds capped at 30 s; a dropped download resumes with
  `Range` and `If-Range` (a strong `ETag`, else `Last-Modified`), appending
  on a 206 that starts where it stopped; 60 s for the response and for each
  gap in the stream; then the next location. `DownloadException` lists every
  location's failure. Tests:
  `packages/mediapipe-core/test/native_assets/verified_download_test.dart`,
  through the `retryWait` hook so they never sleep.
- **Generation pins for comparison runs** (#100).
  `packages/mediapipe-core/tool/pin_nightly.py --generation` pins the archive
  URL to `...zip?generation=<x-goog-generation>`, which Google's bucket keeps
  when the name is uploaded again, so a nightly under comparison needs no
  mirror. An adopted build keeps the plain URL and gets a mirror release.
- **CI's own downloads** (#98). `.github/actions/setup` and
  `.github/actions/apt-install` cache the Linux packages, fail fast on a slow
  apt mirror and switch mirrors; `.github/actions/android-ndk` installs the
  NDK with four attempts; the Android jobs install their system image in a
  retried step.

## Today

| Asset | Fetched by | From | Fallback today |
| --- | --- | --- | --- |
| Browser runtime: bundle and WASM | each family's `assets/worker.js`, through core's `assets/verified_runtime.js` | `cdn.jsdelivr.net` (`MediaPipeWebRuntime.defaultBaseUrl`) | none: one `baseUrl`, one `fetch` per file |
| Native per-family libraries | build hooks, through `downloadVerified` | Google's archive on `storage.googleapis.com` (`familyRuntimeArchiveUrl`) | this project's release (`familyRuntimeBaseUrl`), with retries on both |
| Reference wheels, for generating test references | reference tools, pinned in `reference_wheels.dart` | `files.pythonhosted.org` | none |
| Models, native | `ModelStore`, `bundle_models`, through `downloadVerified` | `storage.googleapis.com`, `huggingface.co` | `DownloadAsset.mirrors`, but no pin names one; retried |
| Models, web | `ModelStore` (`model_store_web.dart`), workers given a `modelPath` | the same | the same mirrors, one `fetch` each |
| npm tarball for the `web_runtime` command | `web_runtime_host.dart` | `registry.npmjs.org` | none |

Decision Maker's Windows library no longer comes from a wheel: Google's
October 18 archive has `decision/windows_x86_64/mediapipe_tasks_decision.dll`.

What already helps in browsers:

- `dart run mediapipe_core:web_runtime web/mediapipe` and
  `MediaPipeWebRuntime.baseUrl = 'mediapipe/'` self-host the browser runtime.
  It is opt-in, takes a step after every runtime bump, and copies all seven
  files `runtime.json` lists, though a browser loads three of them (below).
- `DownloadAsset.mirrors` are tried in order. The `asset_source` user define,
  `ModelStore(source: ...)` and `MEDIAPIPE_ASSET_SOURCE` replace every host
  with one SHA-named directory or URL, deliberately with no fallback, for
  offline builds. `tool/mirror_runtime_assets.py` lists every pin with a
  release asset name (`<sha256>-<file>`) and its license.
- Every file is checked against its pin: SHA-256 for native downloads,
  SHA-384 for browser files.

What is missing: the browser side (`verified_runtime.js`,
`model_store_web.dart`'s `_fetch`, and the workers' `fetch(modelPath)` in
`mediapipe-task-vision` and `mediapipe-task-retrieval`) makes one `fetch`
per file and location, with no retry and no timeout of its own.

## Findings that shape the design

**A browser loads three files per family.** The loader calls
`FilesetResolver.for<Family>Tasks('wasm', true)`. With `true` (use a module),
Google's resolver skips its SIMD check and always returns the module build.
From `text_bundle.mjs` 1.2.0-rc.20261018, read on 2026-10-22, unchanged
since 1.0.1:

```js
async function Wo(t){if(t)return!0; /* ...SIMD probe... */}
async function Ho(t,e,r){return{wasmLoaderPath:`${e}/${t}_${r=`wasm${r?"_module":""}${await Wo(r)?"":"_nosimd"}_internal`}.js`,wasmBinaryPath:`${e}/${t}_${r}.wasm`}}
```

So the files are `<family>_bundle.mjs` and
`wasm/<family>_wasm_module_internal.{js,wasm}`. The SIMD and no-SIMD builds
in `runtime.json` are never loaded, and `verified_runtime.js`'s comment that
the resolver "only picks the variant this browser supports (SIMD or not)" is
wrong for this call.

**Sizes.** The three files of the pinned 1.2.0-rc.20261018 runtimes,
measured on 2026-10-22: vision 15.0 MB, text 7.4, audio 7.0, retrieval 23.7,
decision 26.1, so 79 MB for all five. `gzip -9` takes retrieval's 23.4 MB
WASM to 6.7 MB (29%), and all fifteen files to 23 MB. All seven files are
about three times that (npm unpacked: vision 46 MB, text 24, audio 23,
retrieval 73, decision 81). pub.dev refuses a package over 100 MB. The
repository's pack is 73 MB. The browser pins have moved once since they were
added: #89 (2026-10-19) took all five to 1.2.0-rc.20261018, from 1.0.1 for
vision, text and audio and 1.1.0 for decision and retrieval. Committed files
would grow the history by about 23 MB compressed at each bump of all five.

**Cross-origin rules decide which hosts a browser can use.** A worker
fetching from another origin needs `Access-Control-Allow-Origin` on the
response. Checked on 2026-10-22 with an `Origin` header:

| Host | CORS | Usable by browsers |
| --- | --- | --- |
| The app's own origin | not needed | yes |
| jsDelivr, unpkg | `*` | yes |
| GitHub Pages | `*` | yes, but a site is capped at 1 GB |
| GitHub Release downloads | none (on the 302 and the final 206) | no |
| Google's `mediapipe-assets` bucket | `*` | yes, but it holds no browser runtimes (its `prebuilts/` has `android/`, `desktop/`, `ios/` and `mediapipe_tasks_c/`) |

The host's `Content-Type` does not matter: the loader wraps the checked bytes
in blob URLs with the right MIME type itself.

**Range requests work on every native host.** `curl -r 0-99` got HTTP 206
from Google's archive, the mirror release (through
`release-assets.githubusercontent.com`) and `huggingface.co` on 2026-10-22.
Neither Google's bucket nor the mirror release honors `If-Range`: given an
`ETag` that does not match, both still answered 206 rather than 200. A file
that changed between attempts is caught by the final SHA-256 check, not by
the host.

**Licenses allow it.** Google's npm runtimes are Apache-2.0 (`package.json`'s
`license`), and since 1.2.0-rc.20261018 each tarball carries `LICENSE` and
`NOTICE` files, so the packages may ship the runtimes with those files, as
core already does for the native libraries in
`packages/mediapipe-core/third_party/`. Models need a check per model before
anyone mirrors them: `mirror_runtime_assets.py` marks the Gemma-based ones
`Gemma Terms`, whose notice must travel with every copy.

**A shared CDN no longer saves downloads.** Browsers partition their HTTP
cache by top-level site (Chrome since 86, Firefox since 85, Safari earlier),
so a copy another site loaded from jsDelivr is not reused. Serving from the
app's origin loses no caching.

## Plan

### 1. Ship the browser runtime in each family package

Each family declares its three files as web-only assets, next to the ones it
already has (text shown):

```yaml
flutter:
  assets:
    - path: assets/worker.js
      platforms: [web]
    - path: assets/runtime.json
      platforms: [web]
    - path: assets/runtime/text_bundle.mjs
      platforms: [web]
    - path: assets/runtime/wasm/text_wasm_module_internal.js
      platforms: [web]
    - path: assets/runtime/wasm/text_wasm_module_internal.wasm
      platforms: [web]
```

Flutter serves them at `assets/packages/mediapipe_text/assets/runtime/`, the
worker's own folder plus `runtime/`, so the worker finds them without any app
setting. Native builds leave them out.

A command (core's `web_runtime_host.dart` already downloads the npm tarball
and checks its integrity) writes the files on a runtime bump, and a test
checks each committed file against `runtime.json`'s SHA-384, so a bump cannot
leave stale files behind. `runtime.json` can then list only the three files.

### 2. Try hosts in order in the browser

`verified_runtime.js` takes a list of roots instead of one. Every root must
serve the pinned bytes; a root that fails, after retries, or serves other
bytes passes the file to the next one:

```js
// The copy this package ships comes first; npm-style roots follow.
const roots = [
  new URL('runtime/', import.meta.url),
  ...npmRoots.map(root => new URL(`${pin.package}@${pin.version}/`, root)),
];

async function verified(name) {
  const failures = [];
  for (const root of roots) {
    try {
      const bytes = await fetchWithRetries(new URL(name, root));
      if (await sha384(bytes) === pin.sha384[name]) return bytes;
      failures.push(`${root}: SHA-384 mismatch`);
    } catch (error) {
      failures.push(`${root}: ${error.message}`);
    }
  }
  throw new Error(`MediaPipe runtime ${name}: ${failures.join('; ')}`);
}
```

The Dart setting becomes a list. One possible shape (the public API, so
`tool/api_parity`'s snapshots change with it):

```dart
abstract final class MediaPipeWebRuntime {
  /// npm-style roots tried in order after the copy each family package ships.
  static List<String> fallbackUrls = const [
    'https://cdn.jsdelivr.net/npm/',
    'https://unpkg.com/',
  ];

  /// When set, tried before the shipped copy, as `baseUrl` is today.
  static String? baseUrl;
}
```

An app that sets `baseUrl = 'mediapipe/'` keeps working. An app with a strict
Content Security Policy sets `fallbackUrls = const []` and loads only from its
own origin. If Google publishes the browser runtimes in its bucket, which
already allows cross-origin requests, that root goes before jsDelivr.

### 3. Fallback hosts for models

Native libraries are done (above). Models keep Google's or Hugging Face's
URL first and can name a mirror release holding `<sha256>-<file>`, the names
`mirror_runtime_assets.py` already proposes, once each model's license is
checked. A browser can use such a mirror only from a host that sends
`Access-Control-Allow-Origin`, so not from a GitHub release. `asset_source`
stays exclusive: offline builds must never reach the internet.

### 4. Retries in browsers

`downloadVerified` is the reference: the same attempts, transient statuses,
backoff and `Retry-After` handling, and `DownloadException`'s list of every
failure. `model_store_web.dart`'s `_fetch`, the workers' `fetch(modelPath)`
and `verified_runtime.js` share one browser helper with those rules, without
resume, and with `AbortSignal.timeout(60_000)` per attempt. Tests drive the
Dart side with `package:http/testing`'s `MockClient` (for example 503, 503,
then 200) and an injected delay, as `verified_download_test.dart` does, so
they never wait.

## Decisions to take

- **Commit the runtime files or fetch them at publish time.** Committed
  (recommended): a clone, a git dependency, the gallery and CI all work with
  no extra step, at about 23 MB of compressed history for all five families
  now and for each later bump of all five. Fetched at publish (git-ignored,
  kept by a `.pubignore`): git stays small, but a git or path dependency,
  including the gallery, needs a fetch step or falls back to the CDN.
- **Whether Google will host the browser runtimes.** Its bucket allows
  cross-origin requests; ask whether the `@mediapipe/tasks-*` files can go
  there, and how long dated builds stay in it.
- **The `web_runtime` command's future.** With the runtime inside the
  packages it is only for apps that serve it elsewhere; keep it, or deprecate
  it once the shipped copy is proven.
- **Which models to mirror,** after each one's license check.

## Also

- `doc/privacy_and_licenses.md` lists `cdn.jsdelivr.net` as the browser
  runtime's host; it changes with this, as do the READMEs of core and vision
  that say the runtime loads from jsDelivr.
- `gallery/tool/browser/test_browser.mjs` defaults its runtime roots to
  jsDelivr for the comparisons with Google's JavaScript; CI already passes it
  a self-hosted copy.
- One CI run can keep loading from jsDelivr on purpose, as a check that the
  fallback still works, without making every run depend on it.

## Not tried

- Blocking a host in the browser tests (Playwright's `route`) to prove each
  fallback: whether routing sees a dedicated worker's requests in all three
  engines. Pointing a root at a closed local port is the alternative.
- Shipping the files: Flutter's handling of a 26 MB web asset in `flutter
  build web` and `flutter run -d chrome`, and the size of a published
  package with them.

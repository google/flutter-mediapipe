## 0.3.0

- Upgrade every mediapipe package to 0.3.0 together. MediaPipe 1.2.3
  changes the layout of the native option structs, so this package now
  requires `mediapipe_core` ^0.3.0.
- Runs Google's MediaPipe 1.2.3 instead of 1.2.2, with new SHA-256 pins
  for its native libraries.
- Accepts Flutter 3.44 and newer, down from 3.47. The package accepts the
  dependency versions Flutter 3.44 resolves, from `hooks` 2.0.0 and
  `code_assets` 1.1.0. iOS and macOS builds with Xcode 27 need Flutter
  3.47 or later.
- CI tests the package on Flutter 3.50.0, the latest stable release,
  instead of 3.47.9.

## 0.2.1

- The README has samples for image and audio embeddings, an index that mixes
  text, image and audio records, metadata filters, `minSimilarity`, deleting
  records and an index kept in a database file. The samples dispose the
  embedder when the retriever fails to create, and take the delegate from
  the capability query, so they run on the GPU in browsers.
- `SemanticRetrieverOptions.databasePath`'s doc comment says that in browsers
  `SemanticRetriever.create` throws when it is set.
- The README names MediaPipe 1.2.2 as the native runtime.

## 0.2.0

- Google's MediaPipe 1.2.2 native release (build of November 2, 2026)
  replaces 1.2.0 on Android, iOS, macOS, Linux and Windows, and
  `@mediapipe/tasks-*` 1.2.2 replaces 1.2.0-rc.20261018 in browsers.
- Binds the 1.2.2 retrieval C API: Semantic Retriever options now lead with
  Google's base options, which the retriever fills as the other tasks do, so
  Google's usage log records the host for it too. Universal Embedder takes
  Google's per-modality delegate fields, left at their default.

## 0.1.4

- Error messages and the README no longer refer to removed notes.

## 0.1.3

- The README has an installation section using `flutter pub add`.
- With `mediapipe_core` 0.1.3, downloads of models and native libraries wait out
  short network failures.

## 0.1.2

Release 0.1.2.

## 0.1.1

Adds Google's `NOTICE` at the package root.

## 0.1.0

The first release.

- Universal Embedder and Semantic Retriever on Android, iOS, macOS, Linux,
  Windows and the web, through Google's official MediaPipe runtimes: its
  per-family 1.2.0 retrieval C library natively and `@mediapipe/tasks-retrieval`
  in browsers.
- Universal Embedder and Semantic Retriever need 64-bit Android: 32-bit
  (armeabi-v7a) cannot hold their models, and their capability queries say
  so.
- `UniversalEmbedder` embeds text, encoded images and audio samples into one
  space, with `cosineSimilarity`; `SemanticRetriever` indexes documents,
  images, audio and mixed content with metadata and retrieves the nearest
  records, with the same results on every platform.
- `RetrievalModels` pins Google's EmbeddingGemma 2 models.
- Neither task is offered in WebKit, where Google's browser runtime returns
  zeros for every input with both models.

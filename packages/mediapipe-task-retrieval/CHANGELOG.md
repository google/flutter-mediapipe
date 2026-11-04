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
  zeros for every input with both models (UP-054).

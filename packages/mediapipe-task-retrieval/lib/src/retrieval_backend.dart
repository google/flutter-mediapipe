/// The hook through which this package's web code runs Google's retrieval
/// tasks on its browser runtime; the native worker implements it too.
library;

/// One Universal Embedder on one runtime, and the Semantic Retrievers built
/// on it, which share its worker so they can share its model.
abstract interface class RetrievalBackend {
  /// Runs one [request] and returns the result as JSON-like values.
  ///
  /// A request has a `method`: `embedText`, `embedImage` or `embedAudio`
  /// with its input, or a `retriever.*` method with the `retriever` id that
  /// `retriever.create` returned and the arguments named as in Google's
  /// JavaScript API. Image bytes and audio samples travel as typed data.
  Future<Object?> run(Map<String, Object?> request);

  /// Waits for queued requests, closes the retrievers still open, then the
  /// embedder.
  Future<void> dispose();
}

/// Creates Google's Universal Embedder from `options` named as in Google's
/// JavaScript API (`l2Normalize`, `maxInputLength`, `visionTokensPerImage`,
/// `activationDataType`, `delegate`), plus `modelBytes` (a `Uint8List`) or
/// `modelPath` (a URL).
///
/// Installed by this package's web code in browsers; null where the package
/// runs Google's runtime itself.
Future<RetrievalBackend> Function(Map<String, Object?> options)?
retrievalBackendFactory;

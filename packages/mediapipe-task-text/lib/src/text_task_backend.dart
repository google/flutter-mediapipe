/// The hook through which this package's web code runs the classic text
/// tasks and EmbeddingGemma on Google's browser runtime.
library;

/// One of Google's text tasks, created and run by a platform backend.
abstract interface class TextTaskBackend {
  /// Runs [text] with the request's [arguments], named as in Google's
  /// JavaScript API (the embedder's `formatContext`), and returns Google's
  /// result as JSON values.
  Future<Map<String, dynamic>> run(
    String text, [
    Map<String, Object?> arguments = const {},
  ]);

  /// Waits for queued requests, then closes Google's task.
  Future<void> dispose();
}

/// Creates Google's `task` (`text_classifier`, `text_embedder` or
/// `language_detector`) from `options` named as in Google's JavaScript API,
/// plus `modelBytes` (a `Uint8List`) or `modelPath` (a URL).
///
/// Installed by this package's web code in browsers; null where the package
/// runs Google's runtime itself.
Future<TextTaskBackend> Function(String task, Map<String, Object?> options)?
textTaskBackendFactory;

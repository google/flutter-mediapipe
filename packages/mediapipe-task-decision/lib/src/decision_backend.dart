/// The hook through which this package's web code runs Decision Maker on
/// Google's browser runtime; the native worker implements it too.
library;

/// Google's Decision Maker on one runtime.
abstract interface class DecisionBackend {
  /// Runs one [request] and returns Google's result as JSON values.
  ///
  /// A request has a `method` (`boolean`, `choice`, `score`, or one of them
  /// with `Batch`), the `text` or `texts`, the `question` named as in
  /// Google's JavaScript API and, for a batch, an optional `sharedPrefix`.
  Future<Object?> run(Map<String, Object?> request);

  /// Waits for queued requests, then closes Google's task.
  Future<void> dispose();
}

/// Creates Google's Decision Maker from `options` named as in Google's
/// JavaScript API (`maxNumTokens`, `delegate`), plus `modelBytes` (a
/// `Uint8List`) or `modelPath` (a URL).
///
/// Installed by this package's web code in browsers; null where the package
/// runs Google's runtime itself.
Future<DecisionBackend> Function(Map<String, Object?> options)?
decisionBackendFactory;

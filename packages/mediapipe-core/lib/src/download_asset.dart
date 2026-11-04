/// A reviewed download. Every location must serve the same pinned bytes.
final class DownloadAsset {
  /// Names the primary URL and any published mirrors, in order.
  const DownloadAsset({
    required this.url,
    required this.sha256,
    this.mirrors = const [],
  });

  /// The primary URL. One whose path ends in `.zip` and that has a
  /// fragment names that member of the archive, such as
  /// `https://host/libraries.zip#text/linux_x86_64/libtext.so`.
  final String url;

  /// SHA-256 of the only accepted bytes.
  final String sha256;

  /// Published alternative URLs, which may name zip members as [url] can.
  final List<String> mirrors;

  /// Every source in fallback order.
  Iterable<String> get urls => [url, ...mirrors];
}

/// One unsuccessful source.
final class DownloadFailure {
  /// Explains why [url] did not provide the pinned bytes.
  const DownloadFailure(this.url, this.reason);

  /// Source URL.
  final String url;

  /// HTTP, transport or checksum failure.
  final String reason;
}

/// Every source failed to provide the pinned bytes.
final class DownloadException implements Exception {
  /// The failures, in attempt order.
  const DownloadException(this.failures);

  /// One reason for every attempted source.
  final List<DownloadFailure> failures;

  @override
  String toString() =>
      'Verified download failed: ${failures.map((failure) => '${failure.url}: ${failure.reason}').join('; ')}';
}

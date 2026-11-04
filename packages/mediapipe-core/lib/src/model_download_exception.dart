import 'download_asset.dart';
import 'exceptions.dart';

/// A model could not be downloaded from any configured source.
final class ModelDownloadException extends MediaPipeException {
  /// Preserves every attempted source and its failure.
  const ModelDownloadException(this.failures, this.hint)
    : super('Model download failed.');

  /// One failure per attempted URL.
  final List<DownloadFailure> failures;

  /// A platform-specific network configuration hint, when applicable.
  final String? hint;

  @override
  String toString() =>
      'Model download failed: ${DownloadException(failures)}'
      '${hint == null ? '' : ' $hint'}';
}

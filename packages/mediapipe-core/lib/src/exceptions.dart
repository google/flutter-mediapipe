/// Failures reported by MediaPipe tasks and model loading.
library;

/// A failure from MediaPipe or its supporting runtime.
///
/// Catch it for every MediaPipe failure. Its subtypes separate a platform or
/// setup that cannot run the task ([RuntimeUnavailableException]), a model
/// that could not be downloaded (`ModelDownloadException`), and a task that
/// failed inside Google's runtime ([TaskException]). Programming errors such
/// as invalid options and use after disposal remain [ArgumentError] and
/// [StateError], on every platform.
class MediaPipeException implements Exception {
  /// Creates a failure with a human-readable [message] and optional [cause].
  const MediaPipeException(this.message, {this.cause});

  /// A description suitable for logs or an error message.
  final String message;

  /// The original failure, if one was available.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// The platform cannot load a task runtime required by this operation.
final class RuntimeUnavailableException extends MediaPipeException {
  /// Creates a runtime failure with actionable [fix] text.
  const RuntimeUnavailableException(
    super.message, {
    required this.fix,
    super.cause,
  });

  /// The setup change needed to make the runtime available.
  final String fix;

  @override
  String toString() => '$runtimeType: $message $fix';
}

/// A failure Google's runtime reported while creating or running a task, on
/// any platform and in any family.
final class TaskException extends MediaPipeException {
  /// Preserves Google's message, an optional native status code and whether
  /// the failure was a refused GPU.
  const TaskException(
    super.message, {
    this.statusCode,
    this.gpuUnavailable = false,
    super.cause,
  });

  /// MediaPipe's status code, when the failure came from its native API.
  final int? statusCode;

  /// True when MediaPipe refused `Delegate.gpu` on this machine, for example
  /// on Linux without EGL or with only a software renderer such as llvmpipe.
  /// The package never retries on the CPU; create a CPU task instead.
  final bool gpuUnavailable;

  @override
  String toString() =>
      'TaskException${statusCode == null ? '' : '($statusCode)'}: $message';
}

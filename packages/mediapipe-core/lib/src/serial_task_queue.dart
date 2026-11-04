/// The order and the failures every family's requests share: one request at
/// a time, in call order, and every failure reported as the same exception.
library;

import 'dart:async';

import 'exceptions.dart';

/// Google's failure as the one exception every task reports: a
/// [MediaPipeException] as it is, and anything else as a [TaskException]
/// that keeps it as its cause.
MediaPipeException taskException(Object error) =>
    error is MediaPipeException ? error : TaskException('$error', cause: error);

/// A task's requests, run one at a time in the order they were added. A
/// request that fails does not stop the next, and [close] waits for every
/// request added before it.
final class SerialTaskQueue {
  /// A queue for one task, which its disposal error names, such as
  /// `'DecisionMaker'`.
  SerialTaskQueue(this._name);

  final String _name;
  Future<void> _tail = Future.value();
  Future<void>? _closing;

  /// Runs [request] after every request added before it and reports its
  /// failure as [taskException] does; a [StateError] once [close] is called.
  Future<T> add<T>(FutureOr<T> Function() request) {
    if (_closing != null) {
      return Future.error(StateError('$_name has been disposed.'));
    }
    final result = _tail.then((_) => _reported(request));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Runs [release] once every request added has finished. Later calls
  /// return the same completion.
  Future<void> close(FutureOr<void> Function() release) =>
      _closing ??= _tail.then((_) => _reported(release));
}

Future<T> _reported<T>(FutureOr<T> Function() call) async {
  try {
    return await call();
  } catch (error, stack) {
    Error.throwWithStackTrace(taskException(error), stack);
  }
}

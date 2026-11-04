/// One worker isolate per task, for the family packages' native runtimes:
/// requests from the calling isolate run there one at a time, in call order,
/// on a [WorkerTask] that is made, used and closed there. Not for
/// applications, and not for browsers, which have no isolates.
library;

import 'dart:async';
import 'dart:isolate';

import 'src/exceptions.dart';
import 'src/serial_task_queue.dart' show taskException;

/// A task's native side, made, used and closed on its worker isolate only.
/// [I] is a request, [R] its result and [U] a streamed update.
abstract base class WorkerTask<I, R, U> {
  /// For subclasses, which the `create` function given to [TaskWorker.start]
  /// makes on the worker isolate.
  WorkerTask();

  /// Runs one request to its result.
  R run(I input);

  /// Runs one request whose results arrive through [emit], and returns after
  /// the last of them.
  Future<void> stream(I input, void Function(U update) emit) =>
      throw UnsupportedError('$runtimeType has no streaming requests.');

  /// Releases the native task, once, after every request.
  void close();
}

/// A [WorkerTask] on its own isolate. Requests run in call order, a stream
/// stops delivering when its listener cancels, and [dispose] closes the task
/// after every request accepted before it. Once the worker fails, every
/// request fails with that error.
base class TaskWorker<I extends Object, R, U> {
  /// A worker for one task, which its errors name, such as
  /// `'DecisionMaker'`; the optional callback hears the worker's failure as
  /// it happens.
  TaskWorker(this._name, [this._onFailure]) {
    _events.listen(_receive);
  }

  final String _name;
  final void Function(MediaPipeException error)? _onFailure;
  final _events = ReceivePort();
  final _ready = Completer<void>();
  final _exited = Completer<void>();
  final _pending = <int, _Request<R, U>>{};
  SendPort? _commands;
  var _nextId = 0;
  var _disposing = false;
  Future<void>? _disposal;
  MediaPipeException? _failure;

  /// Spawns the worker, where [create] makes the task from [options], and
  /// completes once the task exists or with what kept it from existing.
  /// [create] must be sendable: a top-level function or a constructor
  /// tear-off.
  Future<void> start<O>(
    O options,
    WorkerTask<I, R, U> Function(O) create,
  ) async {
    try {
      await Isolate.spawn(
        _main<I, R, U, O>,
        (_events.sendPort, options, create),
        onError: _events.sendPort,
        onExit: _events.sendPort,
        debugName: 'MediaPipe $_name',
      );
    } catch (error, stack) {
      _events.close();
      Error.throwWithStackTrace(error, stack);
    }
    try {
      await _ready.future;
    } catch (_) {
      await _exited.future;
      rethrow;
    }
  }

  /// Runs [input] after every request before it.
  Future<R> run(I input) async {
    _check();
    return (await _send(input, false).result.future) as R;
  }

  /// Streams [input]'s updates once listened to; cancelling stops delivery
  /// and waits for the worker to finish the request.
  Stream<U> stream(I input) {
    _check();
    late StreamController<U> controller;
    _Request<R, U>? request;
    controller = StreamController<U>(
      onListen: () {
        try {
          _check();
          request = _send(input, true, controller);
        } catch (error, stack) {
          controller.addError(error, stack);
          unawaited(controller.close());
        }
      },
      onCancel: () async {
        final active = request;
        if (active == null) return;
        active.cancelled = true;
        await active.finished.future;
      },
    );
    return controller.stream;
  }

  /// Closes the task after every accepted request, then waits for the
  /// worker to exit. Repeated calls return the same completion.
  Future<void> dispose() {
    _disposing = true;
    return _disposal ??= _close();
  }

  void _check() {
    if (_disposing) throw StateError('$_name has been disposed.');
    if (_failure case final error?) throw error;
  }

  _Request<R, U> _send(
    I? input,
    bool streaming, [
    StreamController<U>? updates,
  ]) {
    final request = _Request<R, U>(updates);
    final id = _nextId++;
    _pending[id] = request;
    _commands!.send((id, input, streaming));
    return request;
  }

  Future<void> _close() async {
    try {
      if (_failure == null) await _send(null, false).result.future;
    } finally {
      await _exited.future;
    }
  }

  void _receive(Object? event) {
    switch (event) {
      case SendPort port:
        _commands = port;
        _ready.complete();
      case (int id, U update):
        final request = _pending[id];
        if (request != null && !request.cancelled) request.updates?.add(update);
      case (int id, R? result, MediaPipeException? error):
        _pending.remove(id)?.complete(result, error);
      case MediaPipeException error:
        _fail(error);
      case List<Object?> error:
        _fail(TaskException('$_name worker failed: ${error.join('\n')}'));
      case null:
        if (!_ready.isCompleted || _pending.isNotEmpty || !_disposing) {
          _fail(TaskException('$_name worker exited.'));
        }
        _events.close();
        _exited.complete();
    }
  }

  void _fail(MediaPipeException error) {
    if (_failure != null) return;
    _failure = error;
    _onFailure?.call(error);
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final request in _pending.values) {
      request.complete(null, error);
    }
    _pending.clear();
  }
}

final class _Request<R, U> {
  _Request([this.updates]);
  final StreamController<U>? updates;
  final result = Completer<R?>();
  final finished = Completer<void>();
  var cancelled = false;

  void complete(R? value, MediaPipeException? error) {
    finished.complete();
    if (updates case final stream?) {
      if (error != null && !cancelled) stream.addError(error);
      unawaited(stream.close());
    } else if (error != null) {
      result.completeError(error);
    } else {
      result.complete(value);
    }
  }
}

Future<void> _main<I, R, U, O>(
  (SendPort, O, WorkerTask<I, R, U> Function(O)) initial,
) async {
  final (parent, options, create) = initial;
  final commands = ReceivePort();
  WorkerTask<I, R, U>? task;
  try {
    task = create(options);
    parent.send(commands.sendPort);
    await for (final message in commands) {
      final (id, input, streaming) = message as (int, I?, bool);
      R? result;
      MediaPipeException? failure;
      try {
        if (input == null) {
          final closing = task!;
          task = null;
          closing.close();
        } else if (streaming) {
          await task!.stream(input, (update) => parent.send((id, update)));
        } else {
          result = task!.run(input);
        }
      } catch (error) {
        failure = taskException(error);
      }
      parent.send((id, result, failure));
      if (input == null) break;
    }
  } catch (error) {
    parent.send(taskException(error));
  } finally {
    try {
      task?.close();
    } finally {
      commands.close();
    }
  }
}

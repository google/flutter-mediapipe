/// Google's native audio stream on a worker isolate of its own: the isolate
/// owns Google's task from creation to close, since a block can wait in
/// Google's call while its input queue is full and the close runs the
/// tail's inference.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart' show nativeString;
import 'package:mediapipe_core/platform_interface.dart' show taskException;

import '../runner.dart';
import '../stream/results.dart';
import '../third_party/mediapipe/audio_classifier_bindings.dart' as mp;
import '../third_party/mediapipe/audio_stream_bindings.dart' as bridge;
import '../types.dart';
import 'native_audio_classifier.dart';

/// Opens Google's audio stream on a worker isolate, delivering to [results].
Future<AudioStreamRunner> openNativeAudioStream(
  AudioClassifierOptions options,
  AudioStreamResults results,
) async {
  requireNativeAudioRuntime();
  final stream = _NativeAudioStream(results);
  try {
    await Isolate.spawn(
      _worker,
      (stream._events.sendPort, options),
      onError: stream._events.sendPort,
      onExit: stream._events.sendPort,
      debugName: 'MediaPipe audio stream',
    );
  } catch (error, stack) {
    stream._events.close();
    Error.throwWithStackTrace(error, stack);
  }
  try {
    await stream._ready.future;
  } catch (_) {
    await stream._exited.future;
    rethrow;
  }
  return stream;
}

/// The calling isolate's side: blocks go to the worker in order, and the
/// worker's copies of Google's results come back in order.
final class _NativeAudioStream implements AudioStreamRunner {
  _NativeAudioStream(this._results) {
    _events.listen(_receive);
  }

  final AudioStreamResults _results;
  final _events = ReceivePort();
  final _ready = Completer<void>();
  final _exited = Completer<void>();
  SendPort? _commands;
  var _closeSent = false;
  var _closed = false;

  @override
  void send(AudioData block, int timestampMilliseconds) => _commands!.send((
    block.samples,
    block.sampleRate,
    block.channels,
    timestampMilliseconds,
  ));

  /// Asks the worker to close Google's task, which flushes the tail, then
  /// waits for the worker to exit after its last result.
  @override
  Future<void> close() {
    if (!_closeSent && !_exited.isCompleted) {
      _closeSent = true;
      _commands!.send(null);
    }
    return _exited.future;
  }

  void _receive(Object? message) {
    switch (message) {
      case SendPort port:
        _commands = port;
        _ready.complete();
      case AudioClassifierResult result:
        _results.addGoogle(result);
      case MediaPipeException error:
        _fail(error);
      case #closed:
        _closed = true;
      case List<Object?> error:
        _fail(TaskException('Audio stream worker failed: ${error.join('\n')}'));
      case null:
        // A worker that exits without having closed Google's task has died.
        if (!_closed) _fail(const TaskException('Audio stream worker exited.'));
        _events.close();
        _exited.complete();
    }
  }

  /// Fails the creation, or, once the stream is open, the stream.
  void _fail(MediaPipeException error) {
    if (!_ready.isCompleted) {
      _ready.completeError(error);
    } else if (_commands != null) {
      _results.fail(error);
    }
  }
}

/// A block as the calling isolate sends it.
typedef _Block = (Float32List, double, int, int);

Future<void> _worker((SendPort, AudioClassifierOptions) initial) async {
  final (parent, options) = initial;
  final commands = ReceivePort();
  // The bridge posts each copy's address here from Google's threads, then
  // null for the end. A port, unlike a NativeCallable, refuses a message once
  // this isolate has gone, as at a hot restart, so a graph that outlives the
  // isolate cannot crash the process.
  final events = ReceivePort();
  final ended = Completer<void>();
  events.listen((message) {
    if (message == null) {
      ended.complete();
      return;
    }
    final event = Pointer<bridge.MpFlutterAudioEvent>.fromAddress(
      message as int,
    );
    try {
      parent.send(_decode(event));
    } finally {
      bridge.eventFree(event);
    }
  });
  var slot = -1;
  Pointer<Void> task = nullptr;
  try {
    slot = using((arena) {
      final callback = arena<Pointer<Void>>();
      final slot = bridge.streamAcquire(
        NativeApi.postCObject.cast(),
        events.sendPort.nativePort,
        callback,
      );
      if (slot < 0) {
        throw TaskException(
          'Too many audio streams are open: this package allows '
          '${bridge.streamSlots} at once in one process. Dispose one first; '
          'a stream left open by a hot restart counts until the app '
          'restarts.',
        );
      }
      task = openNativeTask(
        options,
        runningMode: audioStreamMode,
        resultCallback: callback.value,
      );
      return slot;
    });
  } catch (error) {
    if (slot >= 0) bridge.streamRelease(slot);
    events.close();
    commands.close();
    parent.send(taskException(error));
    return;
  }
  parent.send(commands.sendPort);
  var failed = false;
  await for (final message in commands) {
    if (message == null) break;
    // After a failure Google's graph refuses every block, and the calling
    // isolate has already delivered the failure.
    if (failed) continue;
    final (samples, rate, channels, timestamp) = message as _Block;
    try {
      using((arena) {
        // Google copies the samples, so they are freed with the arena.
        final audio = nativeAudioData(samples, rate, channels, arena);
        checkedNativeCall(
          (error) => mp.classifyAsync(task, audio, timestamp, error),
        );
      });
    } catch (error) {
      failed = true;
      parent.send(taskException(error));
    }
  }
  try {
    // Closes the graph's inputs and waits for it, so the tail's callback
    // has run when this returns (task_runner.cc, TaskRunner::Close).
    checkedNativeCall((error) => mp.close(task, error));
  } catch (error) {
    parent.send(taskException(error));
  }
  // The end goes to the same port as the results, after all of them.
  bridge.streamEnd(slot);
  await ended.future;
  bridge.streamRelease(slot);
  events.close();
  commands.close();
  // The reply once Google's task is closed and every result sent.
  parent.send(#closed);
}

/// One copied callback as a result, or Google's failure.
Object _decode(Pointer<bridge.MpFlutterAudioEvent> pointer) {
  if (pointer == nullptr) {
    return const TaskException('Could not copy an audio stream result.');
  }
  final event = pointer.ref;
  if (event.copyError != 0) {
    return TaskException(
      'Could not copy an audio stream result (${event.copyError}).',
    );
  }
  if (event.status != 0) {
    // Google's C callback carries a status and no message
    // (upstream-issues.md UP-038).
    return TaskException(
      "Google's audio stream failed: ${_statusNames[event.status] ?? 'UNKNOWN'} "
      '(status ${event.status}).',
      statusCode: event.status,
    );
  }
  return AudioClassifierResult(
    timestampMilliseconds: event.hasTimestampMs ? event.timestampMs : 0,
    classifications: [
      for (var h = 0; h < event.headsCount; h++)
        Classifications(
          categories: [
            for (var i = 0; i < event.heads[h].categoriesCount; i++)
              MediaPipeCategory(
                index: event.heads[h].categories[i].index,
                score: event.heads[h].categories[i].score,
                categoryName: nativeString(
                  event.heads[h].categories[i].categoryName,
                ),
                displayName: nativeString(
                  event.heads[h].categories[i].displayName,
                ),
              ),
          ],
          headIndex: event.heads[h].headIndex,
          headName: nativeString(event.heads[h].headName),
        ),
    ],
  );
}

/// absl::StatusCode names, which Google's MpStatus follows.
const _statusNames = {
  1: 'CANCELLED',
  2: 'UNKNOWN',
  3: 'INVALID_ARGUMENT',
  4: 'DEADLINE_EXCEEDED',
  5: 'NOT_FOUND',
  6: 'ALREADY_EXISTS',
  7: 'PERMISSION_DENIED',
  8: 'RESOURCE_EXHAUSTED',
  9: 'FAILED_PRECONDITION',
  10: 'ABORTED',
  11: 'OUT_OF_RANGE',
  12: 'UNIMPLEMENTED',
  13: 'INTERNAL',
  14: 'UNAVAILABLE',
  15: 'DATA_LOSS',
  16: 'UNAUTHENTICATED',
};

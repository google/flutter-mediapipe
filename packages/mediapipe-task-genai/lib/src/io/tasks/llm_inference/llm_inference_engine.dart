// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_genai/interface.dart';
import 'package:mediapipe_genai/io.dart';

final _log = Logger('LlmInferenceEngine');

/// {@macro LlmInferenceEngine}
class LlmInferenceEngine extends BaseLlmInferenceEngine {
  /// {@macro LlmInferenceEngine}
  LlmInferenceEngine(
    this._options, {
    this.timeout = const Duration(seconds: 10),
    this.maxRetries = 2,
  }) : _readyCompleter = Completer<bool>() {
    _initializeIsolate();
  }

  final LlmInferenceOptions _options;
  StreamController<String>? _responseController;

  /// Length of time the Engine is willing to wait for a response from
  ///  `generateResponse` before assuming that the inference task has failed
  /// and should be resumed.
  final Duration timeout;

  /// Number of times to invoke the timeout loop before giving up.
  final int maxRetries;

  /// Incremented each time [restart] is called, and throws an exception if this
  /// equals [maxRetries] in [restart].
  int _numRetries = 0;

  late SendPort _sendPort;
  late StreamQueue<dynamic> _events;
  Completer<bool> _readyCompleter;
  Future<bool> get _ready => _readyCompleter.future;

  Future<bool> _initializeIsolate() {
    _createIsolate(_options).then((results) {
      _events = results.$1;
      _sendPort = results.$2;
      _readyCompleter.complete(true);
    });
    return _ready;
  }

  /// {@macro generateResponse}
  ///
  /// Creates a [StreamController] for the response, then delegates to
  /// [_tryResponse] which adds retry logic to the task.
  @override
  Stream<String> generateResponse(String text) {
    _log.fine('Generating response to "${text.shorten()}"');
    assert(
      _responseController == null,
      'Should not call `generateResponse` while previous controller is '
      'still active.',
    );
    _responseController = StreamController<String>();
    _tryResponse(text);
    return _responseController!.stream;
  }

  /// Inner workhorse for [generateResponse] which assumes a [StreamController]
  /// already exists and adds retry logic to the actual call to MediaPipe which
  /// is found at [_publishInference].
  void _tryResponse(String text) {
    assert(
      _responseController != null,
      'Should not call `_retryResponse` without an active controller',
    );

    if (_numRetries > 0) {
      _log.info('Retrying for response to "${text.shorten()}"');
    }
    _ready.then((bool success) {
      if (!success) {
        _log.shout('Unable to create inference engine');
        return;
      }
      final responseTimeout = Timer(
        timeout,
        () => restart(() => _tryResponse(text)),
      );
      _publishInference(
        text,
        publish: (String value) {
          _numRetries = 0;
          responseTimeout.cancel();
          _responseController!.add(value);
        },
      );
    });
  }

  /// Sends the text to the isolate running the MediaPipe inference engine,
  /// listens for responses, and passes them to the [publish] callback.
  void _publishInference(
    String text, {
    required void Function(String) publish,
  }) async {
    _sendPort.send(_LlmInferenceTask.respond(text));
    while (true) {
      final response = await _events.next;

      if (response is LlmResponseContext) {
        publish(response.responseArray.join(''));
        if (response.isDone) {
          _log.finer('response.isDone - closing controller from $publish');
          _endResponse();
        }
      } else if (response is String) {
        _log.fine(response);
      } else {
        throw Exception(
          'Unexpected generateResponse result of type ${response.runtimeType} : $response',
        );
      }
    }
  }

  /// Terminates an in-progress query, closing down the stream.
  void cancel() {}

  /// Releases all native resources and closes any open streams.
  void dispose() {
    _endResponse();
    _sendPort.send(null);
  }

  void _endResponse() {
    _responseController?.close();
    _responseController = null;
  }

  /// Powers down the executor and isolate and then powers up another one and
  /// invokes the callback once that replacement executor is awake.
  ///
  /// Throws an exception if [_numRetries] == [maxRetries].
  ///
  /// Do not call [dispose] in this method, as that will close the response
  /// controller which we must reuse, because whoever originally called
  /// [generateResponse] already has its stream and is waiting for a response.
  void restart(void Function() callback) {
    _log.shout('RESTARTING INFERENCE EXECUTOR - REACHED TIMEOUT OF '
        '${timeout.inSeconds} seconds');
    _sendPort.send(null);
    if (_numRetries == maxRetries) {
      throw Exception('Reached retry limit of $maxRetries.');
    }
    _numRetries++;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete(false);
    }
    _readyCompleter = Completer<bool>();
    _initializeIsolate().then(
      (bool success) {
        if (!success) {
          _log.shout('Failed to initialize isolate during restart');
          return;
        }
        callback();
      },
    );
  }

  @override
  Future<int> sizeInTokens(String text) async {
    _log.fine('Counting tokens of "${text.shorten()}"');
    await _ready;
    _sendPort.send(_LlmInferenceTask.countTokens(text));
    while (true) {
      final response = await _events.next;
      if (response is int) {
        return response;
      } else if (response is String) {
        _log.fine(response);
      } else {
        throw Exception(
          'Unexpected sizeInTokens result of type ${response.runtimeType} : $response',
        );
      }
    }
  }
}

Future<(StreamQueue<dynamic>, SendPort)> _createIsolate(
  LlmInferenceOptions options,
) async {
  final p = ReceivePort();
  await Isolate.spawn(
    (SendPort port) => _inferenceService(
      port,
      options,
    ),
    p.sendPort,
  );

  final events = StreamQueue<dynamic>(p);
  final SendPort sendPort = await events.next;
  return (events, sendPort);
}

Future<void> _inferenceService(
  SendPort p,
  LlmInferenceOptions options,
) async {
  final commandPort = ReceivePort();
  p.send(commandPort.sendPort);

  Logger.root.level = Level.FINEST;
  Logger.root.onRecord.listen((record) {
    io.stdout.writeln('${record.level.name} [${record.loggerName}]'
        '['
        '${record.time.hour.toString()}:'
        '${record.time.minute.toString().padLeft(2, "0")}:'
        '${record.time.second.toString().padLeft(2, "0")}.'
        '${record.time.millisecond.toString().padRight(3, "0")}'
        '] ${record.message}');
  });

  final executor = LlmInferenceExecutor(options);

  await for (final _LlmInferenceTask? message in commandPort) {
    if (message != null) {
      switch (message.type) {
        case _LlmInferenceTaskType._respond:
          await for (final response
              in executor.generateResponse(message.text)) {
            p.send(response);
          }
        case _LlmInferenceTaskType._countTokens:
          p.send(executor.sizeInTokens(message.text));
      }
    } else {
      break;
    }
  }
  executor.dispose();
  Isolate.exit();
}

enum _LlmInferenceTaskType { _respond, _countTokens }

class _LlmInferenceTask {
  _LlmInferenceTask._({
    required this.type,
    required this.text,
  });

  factory _LlmInferenceTask.respond(String text) => _LlmInferenceTask._(
        type: _LlmInferenceTaskType._respond,
        text: text,
      );

  factory _LlmInferenceTask.countTokens(String text) => _LlmInferenceTask._(
        type: _LlmInferenceTaskType._respond,
        text: text,
      );

  final _LlmInferenceTaskType type;
  final String text;
}

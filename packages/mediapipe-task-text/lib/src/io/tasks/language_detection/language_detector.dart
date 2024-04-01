// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/io.dart' as core_io;
import 'package:mediapipe_text/interface.dart';
import 'package:mediapipe_text/io.dart';

final _log = Logger('LanguageDetector');

/// LanguageDetector implementation able to use FFI and `dart:io`.
class LanguageDetector extends BaseLanguageDetector {
  /// Generative constructor.
  LanguageDetector(this._options) : _readyCompleter = Completer<void>() {
    _createIsolate(_options).then((results) {
      _events = results.$1;
      _sendPort = results.$2;
      _readyCompleter.complete();
    });
  }

  late SendPort _sendPort;
  late StreamQueue<Object?> _events;
  final Completer<void> _readyCompleter;
  Future<void> get _ready => _readyCompleter.future;

  final LanguageDetectorOptions _options;

  /// Closes down the background isolate, releasing all resources.
  @override
  void dispose() => _sendPort.send(null);

  /// {@macro LanguageDetector.embed}
  @override
  Future<LanguageDetectorResult> detect(String text) async {
    _log.fine('Detecting language of "${text.shorten()}"');
    await _ready;
    _sendPort.send(text);
    while (true) {
      final response = await _events.next;
      if (response is LanguageDetectorResult) {
        return response;
      } else if (response is String) {
        _log.fine(response);
      } else {
        throw Exception(
          'Unexpected language detection result of type ${response.runtimeType} '
          ': $response',
        );
      }
    }
  }
}

Future<(StreamQueue<dynamic>, SendPort)> _createIsolate(
    LanguageDetectorOptions options) async {
  final p = ReceivePort();
  await Isolate.spawn(
    (SendPort port) => _languageDetectionService(
      port,
      options,
    ),
    p.sendPort,
  );

  final events = StreamQueue<dynamic>(p);
  final SendPort sendPort = await events.next;
  return (events, sendPort);
}

Future<void> _languageDetectionService(
  SendPort p,
  LanguageDetectorOptions options,
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

  final executor = LanguageDetectorExecutor(options);

  await for (final String? message in commandPort) {
    if (message != null) {
      final LanguageDetectorResult result = executor.detect(message);
      p.send(result);
    } else {
      break;
    }
  }
  executor.dispose();
  Isolate.exit();
}

enum _EmbedderTaskType { _embed, _cosineSimilarity }

class _EmbedderTask {
  _EmbedderTask._({
    required this.type,
    required this.text,
    required this.a,
    required this.b,
  });

  factory _EmbedderTask.embed(String text) => _EmbedderTask._(
        type: _EmbedderTaskType._embed,
        text: text,
        a: null,
        b: null,
      );

  factory _EmbedderTask.cosineSimilarity(Embedding a, Embedding b) =>
      _EmbedderTask._(
        type: _EmbedderTaskType._cosineSimilarity,
        text: null,
        a: a,
        b: b,
      );

  final _EmbedderTaskType type;
  final String? text;
  final Embedding? a;
  final Embedding? b;
}

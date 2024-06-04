// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/interface.dart';
import 'package:mediapipe_text/io.dart';

final _log = Logger('TextClassifier');

/// {@macro TextClassifier}
class TextClassifier extends BaseTextClassifier {
  /// {@macro TextClassifier}
  TextClassifier(this._options) : _readyCompleter = Completer<void>() {
    _createIsolate(_options).then((results) {
      _events = results.$1;
      _sendPort = results.$2;
      _readyCompleter.complete();
    });
  }

  late SendPort _sendPort;
  late StreamQueue<dynamic> _events;
  final Completer<void> _readyCompleter;
  Future<void> get _ready => _readyCompleter.future;

  final TextClassifierOptions _options;

  @override
  Future<TextClassifierResult> classify(String text) async {
    _log.fine('Classifying ${text.shorten()}');
    await _ready;
    _sendPort.send(text);
    return await _events.next;
  }

  /// Closes down the background isolate, releasing all resources.
  @override
  void dispose() => _sendPort.send(null);
}

Future<(StreamQueue<dynamic>, SendPort)> _createIsolate(
  TextClassifierOptions options,
) async {
  final p = ReceivePort();
  await Isolate.spawn(
    (SendPort port) => _classificationService(
      port,
      options,
    ),
    p.sendPort,
  );

  final events = StreamQueue<dynamic>(p);
  final SendPort sendPort = await events.next;
  return (events, sendPort);
}

Future<void> _classificationService(
  SendPort p,
  TextClassifierOptions options,
) async {
  final commandPort = ReceivePort();
  p.send(commandPort.sendPort);

  final executor = TextClassifierExecutor(options);

  await for (final String? message in commandPort) {
    if (message != null) {
      final TextClassifierResult result = executor.classify(message);
      p.send(result);
    } else {
      break;
    }
  }
  executor.dispose();
  Isolate.exit();
}

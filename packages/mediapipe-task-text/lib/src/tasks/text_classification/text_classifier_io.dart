import 'dart:async';
import 'dart:isolate';
import 'package:async/async.dart';
import 'package:logging/logging.dart';

import 'text_classification_executor.dart';
import 'text_classifier.dart';
import 'containers/containers.dart';

final _log = Logger('TextClassifier');

/// TextClassifier implementation able to use FFI and `dart:io`.
class TextClassifier extends BaseTextClassifier {
  /// Generative constructor.
  TextClassifier({required super.options})
      : _readyCompleter = Completer<void>() {
    _createIsolate(options).then((results) {
      _events = results.$1;
      _sendPort = results.$2;
      _readyCompleter.complete();
    });
  }

  late SendPort _sendPort;
  late StreamQueue<dynamic> _events;
  final Completer<void> _readyCompleter;
  Future<void> get _ready => _readyCompleter.future;

  /// Closes down the background isolate, releasing all resources.
  void dispose() => _sendPort.send(null);

  /// Sends a `String` value to MediaPipe for classification. Uses an Isolate
  /// on mobile and desktop, and a web worker on web, to add concurrency and avoid
  /// blocking the UI thread while this task completes.
  ///
  /// See also:
  ///  * [classify_sync] for a synchronous alternative
  @override
  Future<TextClassifierResult> classify(String text) async {
    _log.info('Classifying "$text"');
    await _ready;
    _sendPort.send(text);
    return await _events.next;
  }
}

Future<(StreamQueue<dynamic>, SendPort)> _createIsolate(
    TextClassifierOptions options) async {
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
  executor.close();
  Isolate.exit();
}

/// Flutter's registration of Google's browser runtime behind the classic
/// text tasks and EmbeddingGemma. Not for applications: import
/// `mediapipe_text.dart`.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:mediapipe_core/web_task_bridge.dart';
import 'package:mediapipe_text/platform_interface.dart';

/// Flutter registration for Google's official browser text runtime.
abstract final class MediaPipeTextWeb {
  /// Installs the browser backend before the first text task is created.
  static void registerWith(Registrar registrar) {
    textTaskBackendFactory = _WorkerTextTask.create;
  }
}

/// One of Google's text tasks on its own worker (assets/worker.js), through
/// core's shared bridge.
final class _WorkerTextTask implements TextTaskBackend {
  _WorkerTextTask._(this._worker);

  final WebTaskWorker _worker;

  static Future<TextTaskBackend> create(
    String task,
    Map<String, Object?> options,
  ) async => _WorkerTextTask._(
    await WebTaskWorker.create('mediapipe_text', {...options, 'task': task}),
  );

  @override
  Future<Map<String, dynamic>> run(
    String text, [
    Map<String, Object?> arguments = const {},
  ]) async =>
      jsonDecode(
            await _worker.run(
              {'text': text, ...arguments}.jsify()! as JSObject,
            ),
          )
          as Map<String, dynamic>;

  @override
  Future<void> dispose() => _worker.close();
}

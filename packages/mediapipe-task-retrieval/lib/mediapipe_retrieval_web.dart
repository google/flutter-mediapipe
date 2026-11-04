/// Flutter's registration of Google's browser runtime behind the retrieval
/// tasks. Not for applications: import `mediapipe_retrieval.dart`.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show taskPlatformGpuReader;
import 'package:mediapipe_core/web_task_bridge.dart';
import 'package:mediapipe_retrieval/platform_interface.dart';

/// Flutter registration for Google's official browser retrieval runtime.
abstract final class MediaPipeRetrievalWeb {
  /// Installs the browser backend before the first task is created.
  static void registerWith(Registrar registrar) {
    retrievalBackendFactory = _WorkerUniversalEmbedder.create;
    // Google's runtime runs only on a hardware WebGPU adapter (UP-052), so
    // the capability query needs to know which one this browser has.
    taskPlatformGpuReader ??= readWebGpuAdapter;
  }
}

/// Google's Universal Embedder, and the Semantic Retrievers built on it, on
/// their own worker (assets/worker.js), through core's shared bridge.
final class _WorkerUniversalEmbedder implements RetrievalBackend {
  _WorkerUniversalEmbedder._(this._worker);

  final WebTaskWorker _worker;

  static Future<RetrievalBackend> create(Map<String, Object?> options) async =>
      _WorkerUniversalEmbedder._(
        await WebTaskWorker.create('mediapipe_retrieval', options),
      );

  @override
  Future<Object?> run(Map<String, Object?> request) async {
    final answer = await _worker.run(request.jsify()! as JSObject);
    return answer.isEmpty ? null : jsonDecode(answer);
  }

  @override
  Future<void> dispose() => _worker.close();
}

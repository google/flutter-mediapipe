/// Flutter's registration of Google's browser runtime behind Decision Maker.
/// Not for applications: import `mediapipe_decision.dart`.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show taskPlatformGpuReader;
import 'package:mediapipe_core/web_task_bridge.dart';
import 'package:mediapipe_decision/platform_interface.dart';

/// Flutter registration for Google's official browser Decision Maker.
abstract final class MediaPipeDecisionWeb {
  /// Installs the browser backend before the first task is created.
  static void registerWith(Registrar registrar) {
    decisionBackendFactory = _WorkerDecisionMaker.create;
    // Google's runtime answers only on a hardware WebGPU adapter (UP-049),
    // so the capability query needs to know which one this browser has.
    taskPlatformGpuReader ??= readWebGpuAdapter;
  }
}

/// Google's Decision Maker on its own worker (assets/worker.js), through
/// core's shared bridge.
final class _WorkerDecisionMaker implements DecisionBackend {
  _WorkerDecisionMaker._(this._worker);

  final WebTaskWorker _worker;

  static Future<DecisionBackend> create(Map<String, Object?> options) async =>
      _WorkerDecisionMaker._(
        await WebTaskWorker.create('mediapipe_decision', options),
      );

  @override
  Future<Object?> run(Map<String, Object?> request) async =>
      jsonDecode(await _worker.run(request.jsify()! as JSObject));

  @override
  Future<void> dispose() => _worker.close();
}

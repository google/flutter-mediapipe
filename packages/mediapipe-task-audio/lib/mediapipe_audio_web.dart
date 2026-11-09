/// Flutter's registration of Google's browser runtime behind the Audio
/// Classifier, Audio Transcriber and Text to Speech. Not for applications:
/// import `mediapipe_audio.dart`.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:mediapipe_audio/platform_interface.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show taskPlatformGpuReader;
import 'package:mediapipe_core/web_task_bridge.dart';
import 'package:web/web.dart' as web;

import 'src/web_speech.dart';

/// Flutter registration for Google's official browser audio runtime.
abstract final class MediaPipeAudioWeb {
  /// Installs the browser backends before the first audio task.
  static void registerWith(Registrar registrar) {
    taskPlatformGpuReader ??= readWebGpuAdapter;
    // An iPad asks for desktop sites with a Mac's user agent, and only its
    // touch points give it away.
    final navigator = web.window.navigator;
    browserOnMac =
        navigator.userAgent.contains('Macintosh') &&
        navigator.maxTouchPoints <= 1;
    audioTaskBackendFactory = _WorkerAudioTask.create;
    audioTranscriberOpener = openWebAudioTranscriber;
    textToSpeechOpener = openWebTextToSpeech;
  }
}

/// Google's Audio Classifier on its own worker (assets/worker.js), through
/// core's shared bridge.
final class _WorkerAudioTask implements AudioTaskBackend {
  _WorkerAudioTask._(this._worker);

  final WebTaskWorker _worker;

  static Future<AudioTaskBackend> create(Map<String, Object?> options) async =>
      _WorkerAudioTask._(
        await WebTaskWorker.create('mediapipe_audio', options),
      );

  @override
  Future<List<Object?>> classify(Float32List samples, double sampleRate) async {
    final input = JSObject()
      ..['samples'] = Float32List.fromList(samples).toJS
      ..['sampleRate'] = sampleRate.toJS;
    return jsonDecode(await _worker.run(input)) as List<Object?>;
  }

  @override
  Future<void> dispose() => _worker.close();
}

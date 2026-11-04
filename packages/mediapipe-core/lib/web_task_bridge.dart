/// The browser plumbing the family plugins share: one worker per task,
/// created from the family's worker script, with requests and disposal in
/// order; the page's scripts; and the WebGPU adapter. Web only, and not for
/// applications.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'src/capabilities/web_gpu.dart';
import 'src/exceptions.dart';
import 'src/web_runtime.dart';

@JS('mediapipeTasks.create')
external JSPromise<JSNumber> _create(JSString workerUrl, JSObject options);
@JS('mediapipeTasks.run')
external JSPromise<JSString> _run(JSNumber id, JSObject input);
@JS('mediapipeTasks.close')
external JSPromise<JSAny?> _close(JSNumber id);

/// One of Google's tasks on its own worker, from the family's
/// `assets/worker.js`.
final class WebTaskWorker {
  WebTaskWorker._(this._id);
  final JSNumber _id;

  /// Starts a worker from [family]'s worker script (`mediapipe_text` or
  /// `mediapipe_audio`) and creates its task from [options]: the task's
  /// settings named as in Google's JavaScript API, plus `modelBytes` or
  /// `modelPath`, a URL resolved against the page.
  static Future<WebTaskWorker> create(
    String family,
    Map<String, Object?> options,
  ) async {
    await loadPackageScript('mediapipe_core', 'assets/task_bridge.js');
    final bytes = options['modelBytes'] as Uint8List?;
    final path = options['modelPath'] as String?;
    final input = {
      ...options,
      'modelBytes': bytes == null ? null : Uint8List.fromList(bytes).toJS,
      'modelPath': path == null ? null : Uri.base.resolve(path).toString(),
      'runtimeBaseUrl': MediaPipeWebRuntime.resolve(Uri.base),
    }.jsify()!;
    final worker = Uri.base.resolve('assets/packages/$family/assets/worker.js');
    return WebTaskWorker._(
      await _reported(_create(worker.toString().toJS, input as JSObject)),
    );
  }

  /// Runs one request after every request submitted before it and returns
  /// the worker's JSON.
  Future<String> run(JSObject input) async =>
      (await _reported(_run(_id, input))).toDart;

  /// Waits for queued requests, then closes the task and its worker.
  Future<void> close() => _reported(_close(_id));
}

/// Google's failure, from the worker, as the one task exception.
Future<T> _reported<T extends JSAny?>(JSPromise<T> promise) async {
  try {
    return await promise.toDart;
  } catch (error) {
    throw TaskException('$error', cause: error);
  }
}

final _scripts = <String, Future<void>>{};

/// Adds [package]'s [asset] (such as `assets/bridge.js`) to the page as a
/// script, once. A failed load is forgotten, so the next call retries it
/// rather than failing every later task.
Future<void> loadPackageScript(String package, String asset) {
  final url = Uri.base.resolve('assets/packages/$package/$asset').toString();
  return _scripts[url] ??= () async {
    final script = web.HTMLScriptElement()..src = url;
    final ready = Completer<void>();
    unawaited(script.onLoad.first.then((_) => ready.complete()));
    unawaited(
      script.onError.first.then((_) {
        ready.completeError(StateError('Unable to load $url.'));
      }),
    );
    web.document.head!.append(script);
    try {
      await ready.future.timeout(const Duration(seconds: 60));
    } catch (_) {
      script.remove();
      // Forget this failed load, so the next call retries it.
      unawaited(_scripts.remove(url));
      rethrow;
    }
  }();
}

@JS('navigator.gpu')
external JSObject? get _gpu;

/// The adapter Google's browser runtimes ask WebGPU for, named for
/// `TaskPlatform.gpu` as `WebGPU` and its vendor, architecture and
/// description, with a fallback adapter marked as such; null without WebGPU.
/// A family whose browser runtime needs WebGPU sets it as
/// `taskPlatformGpuReader` when its plugin registers.
Future<String?> readWebGpuAdapter() async {
  final gpu = _gpu;
  if (gpu == null) return null;
  final adapter = await gpu
      .callMethod<JSPromise<JSObject?>>(
        'requestAdapter'.toJS,
        {'powerPreference': 'high-performance'}.jsify(),
      )
      .toDart;
  if (adapter == null) return null;
  final info = adapter.getProperty<JSObject?>('info'.toJS);
  String part(String name) =>
      info?.getProperty<JSString?>(name.toJS)?.toDart ?? '';
  final fallback =
      adapter.getProperty<JSBoolean?>('isFallbackAdapter'.toJS)?.toDart ??
      false;
  return [
    webGpuAdapterPrefix,
    for (final name in ['vendor', 'architecture', 'description'])
      if (part(name).isNotEmpty) part(name),
    if (fallback) '(fallback adapter)',
  ].join(' ');
}

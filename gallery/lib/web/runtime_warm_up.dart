import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:mediapipe_vision/mediapipe_vision.dart'
    show MediaPipeWebRuntime;
import 'package:web/web.dart' as web;

/// Fetches Google's vision runtime into the browser's HTTP cache while a
/// page's model downloads. The task's worker fetches the same files only once
/// it has the model, so without this the two downloads ran one after the
/// other. The worker still verifies every file against its pin; a failure
/// here only means the worker downloads it itself.
abstract final class WebRuntimeWarmUp {
  static Future<void>? _vision;

  /// Starts once per page load; later calls return the same fetch.
  static Future<void> vision() => _vision ??= _fetchVision();

  static Future<void> _fetchVision() async {
    try {
      final pinUrl = ui_web.assetManager.getAssetUrl(
        'packages/mediapipe_vision/assets/runtime.json',
      );
      final pinResponse = await web.window.fetch(pinUrl.toJS).toDart;
      if (!pinResponse.ok) return;
      final pin =
          jsonDecode((await pinResponse.text().toDart).toDart)
              as Map<String, dynamic>;
      final base = Uri.parse(
        MediaPipeWebRuntime.resolve(Uri.base),
      ).resolve('${pin['package']}@${pin['version']}/');
      // The worker asks Google's resolver for the module build of the WASM
      // (see verified_runtime.js), which every supported browser uses.
      final files = (pin['files'] as List).cast<String>().where(
        (name) => name.endsWith('_bundle.mjs') || name.contains('_module_'),
      );
      await Future.wait([
        for (final name in files)
          () async {
            final response = await web.window
                .fetch(base.resolve(name).toString().toJS)
                .toDart;
            // Only a body read to its end is stored in the cache.
            await response.arrayBuffer().toDart;
          }(),
      ]);
    } catch (_) {
      // The worker fetches what is missing and reports its own failures.
    }
  }
}

import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// The bytes of the app's bundled model with [sha256], fetched as a stream so
/// [onReceived] can follow the download, or null when the fetch fails. The
/// caller verifies them.
Future<Uint8List?> streamBundledModel(
  String sha256,
  void Function(int received) onReceived,
) async {
  try {
    final url = ui_web.assetManager.getAssetUrl('assets/mediapipe/$sha256');
    final response = await web.window.fetch(url.toJS).toDart;
    final body = response.body;
    if (!response.ok || body == null) return null;
    final reader = web.ReadableStreamDefaultReader(body);
    final bytes = BytesBuilder(copy: false);
    while (true) {
      final chunk = await reader.read().toDart;
      if (chunk.done) break;
      bytes.add((chunk.value! as JSUint8Array).toDart);
      onReceived(bytes.length);
    }
    return bytes.takeBytes();
  } catch (_) {
    return null;
  }
}

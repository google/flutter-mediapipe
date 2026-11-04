import 'package:flutter/services.dart';

import 'model_bundle.dart';

/// Why this isolate cannot read the app's assets, or null when it can.
String? bundledModelsUnreadable() {
  try {
    ServicesBinding.instance;
    return null;
  } catch (_) {
    return 'Flutter is not initialized in this isolate, so the app\'s bundled '
        'models cannot be read; call WidgetsFlutterBinding.ensureInitialized() '
        'before creating tasks, on the main isolate.';
  }
}

/// The bytes of the app's bundled copy of the model with [sha256], or null
/// when the app does not bundle it or this isolate cannot read assets.
Future<Uint8List?> readBundledModel(String sha256) async {
  if (bundledModelsUnreadable() != null) return null;
  final key = bundledModelKey(sha256);
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  if (!manifest.listAssets().contains(key)) return null;
  final data = await rootBundle.load(key);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

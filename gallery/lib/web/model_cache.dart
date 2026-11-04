import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart'
    show DownloadAsset, ModelStore;

/// Keeps recently used bundled models in memory across gallery pages.
/// Uploaded models bypass this cache. A small cap avoids retaining the full
/// model catalog on mobile browsers.
abstract final class WebModelCache {
  static const int _maxBytes = 24 * 1024 * 1024;
  static final _models = <String, Uint8List>{};
  static final _loading = <String, Future<Uint8List>>{};
  static int _bytes = 0;
  static Future<void> _prefetches = Future.value();

  static final _store = ModelStore();

  /// The verified bytes of [model], which the app bundles with `dart run
  /// mediapipe_core:bundle_models`.
  static Future<Uint8List> load(DownloadAsset model) {
    final asset = model.sha256;
    final cached = _models.remove(asset);
    if (cached != null) {
      _models[asset] = cached;
      return Future.value(cached);
    }
    // A page and a prefetch asking at once share one download. The block body
    // matters: returning the removed future would make this one wait on itself.
    return _loading[asset] ??= _fetch(model).whenComplete(() {
      _loading.remove(asset);
    });
  }

  static Future<Uint8List> _fetch(DownloadAsset pin) async {
    final asset = pin.sha256;
    final model = (await _store.find(pin))?.bytes;
    if (model == null) {
      throw StateError(
        '${Uri.parse(pin.url).pathSegments.last} is not bundled in this '
        'build. Prepare the gallery again.',
      );
    }
    if (model.lengthInBytes > _maxBytes) return model;

    while (_bytes + model.lengthInBytes > _maxBytes) {
      final oldest = _models.keys.first;
      _bytes -= _models.remove(oldest)!.lengthInBytes;
    }
    _models[asset] = model;
    _bytes += model.lengthInBytes;
    return model;
  }

  /// Fetches [models] one at a time once the models already loading are in,
  /// for the pages a visitor is likely to open next.
  static void prefetch(Iterable<DownloadAsset> models) {
    for (final model in models) {
      _prefetches = _prefetches.then((_) async {
        try {
          await Future.wait(_loading.values.toList());
          await load(model);
        } catch (_) {
          // A page that opens it loads it again and reports the failure.
        }
      });
    }
  }
}

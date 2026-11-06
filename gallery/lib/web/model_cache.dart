import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart'
    show DownloadAsset, ModelStore;

import 'bundled_model_stream_stub.dart'
    if (dart.library.js_interop) 'bundled_model_stream.dart';

/// Bytes of a model received so far, and its whole size when known.
typedef ModelProgress = void Function(int received, int? total);

/// Keeps recently used bundled models in memory across gallery pages.
/// Uploaded models bypass this cache. A small cap avoids retaining the full
/// model catalog on mobile browsers.
abstract final class WebModelCache {
  static const int _maxBytes = 24 * 1024 * 1024;
  static final _models = <String, Uint8List>{};
  static final _loading = <String, Future<Uint8List>>{};
  static final _listeners = <String, List<ModelProgress>>{};
  static final _received = <String, (int, int?)>{};
  static int _bytes = 0;
  static Future<void> _prefetches = Future.value();

  /// Starts the pages are waiting on, which prefetches give way to.
  static final _starts = <Future<void>>{};

  static final _store = ModelStore();

  /// The bundled models' sizes, which `prepare_gallery` records: GitHub Pages
  /// serves them gzipped, so a response's Content-Length is not the size.
  static final Future<Map<String, int>> _sizes = () async {
    try {
      final manifest =
          jsonDecode(await rootBundle.loadString('assets/manifest.json'))
              as Map<String, dynamic>;
      return (manifest['modelBytes'] as Map<String, dynamic>? ?? const {}).map(
        (sha, size) => MapEntry(sha, size as int),
      );
    } catch (_) {
      return const <String, int>{};
    }
  }();

  /// The verified bytes of [model], which the app bundles with `dart run
  /// mediapipe_core:bundle_models`. [onProgress] follows its download, even
  /// one a prefetch started.
  static Future<Uint8List> load(
    DownloadAsset model, {
    ModelProgress? onProgress,
  }) {
    final asset = model.sha256;
    final cached = _models.remove(asset);
    if (cached != null) {
      _models[asset] = cached;
      return Future.value(cached);
    }
    if (onProgress != null) {
      (_listeners[asset] ??= []).add(onProgress);
      if (_received[asset] case (final received, final total)) {
        onProgress(received, total);
      }
    }
    // A page and a prefetch asking at once share one download. The block body
    // matters: returning the removed future would make this one wait on itself.
    return _loading[asset] ??= _fetch(model).whenComplete(() {
      _loading.remove(asset);
      _listeners.remove(asset);
      _received.remove(asset);
    });
  }

  /// Holds back prefetches until [start] completes, so they do not compete
  /// with what a page needs to start.
  static void startingUntil(Future<void> start) {
    final settled = start.then<void>((_) {}, onError: (_) {});
    _starts.add(settled);
    unawaited(settled.whenComplete(() => _starts.remove(settled)));
  }

  static Future<Uint8List> _fetch(DownloadAsset pin) async {
    final asset = pin.sha256;
    final model = await _download(pin) ?? (await _store.find(pin))?.bytes;
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

  /// Streams the bundled copy of [pin], reporting progress, and verifies it as
  /// [ModelStore] does. Null when it is not bundled or the stream fails, which
  /// leaves [ModelStore.find] to read it (and report why it cannot).
  static Future<Uint8List?> _download(DownloadAsset pin) async {
    final asset = pin.sha256;
    final total = (await _sizes)[asset];
    if (total == null) return null;
    _report(asset, 0, total);
    final model = await streamBundledModel(
      asset,
      (received) => _report(asset, received, total),
    );
    if (model == null || sha256.convert(model).toString() != asset) {
      return null;
    }
    return model;
  }

  static void _report(String asset, int received, int total) {
    _received[asset] = (received, total);
    for (final listener in [...?_listeners[asset]]) {
      listener(received, total);
    }
  }

  /// Fetches [models] one at a time once the models already loading are in
  /// and the page has started, for the pages a visitor is likely to open
  /// next.
  static void prefetch(Iterable<DownloadAsset> models) {
    for (final model in models) {
      _prefetches = _prefetches.then((_) async {
        try {
          await Future.wait([..._starts]);
          await Future.wait(_loading.values.toList());
          await load(model);
        } catch (_) {
          // A page that opens it loads it again and reports the failure.
        }
      });
    }
  }
}

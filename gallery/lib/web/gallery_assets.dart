import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart' show DownloadAsset;

import 'model_cache.dart';

/// Browser assets are served directly rather than unpacked to filesystem paths.
final class GalleryAssets {
  const GalleryAssets(this.manifest);
  final Map<String, dynamic> manifest;
  Set<String> get bundledTasks =>
      (manifest['tasks'] as List).cast<String>().toSet();
  String path(String name) =>
      Uri.base.resolve('assets/assets/samples/$name').toString();

  ImageProvider imageProvider(String name) => NetworkImage(path(name));

  /// The URL of the copy of [model] that `dart run
  /// mediapipe_core:bundle_models` bundled, which Google's browser runtime
  /// fetches itself, so a large model never passes through Dart.
  static Future<String> modelPath(DownloadAsset model) async =>
      Uri.base.resolve('assets/assets/mediapipe/${model.sha256}').toString();

  /// [model]'s URL in Google's bucket, which Google's browser runtime
  /// fetches itself: Decision Maker's models are too large to bundle or to
  /// pass through Dart.
  static Future<String> downloadedModelPath(DownloadAsset model) async =>
      model.url;

  /// The bundled copy of [model], verified against its pin.
  static Future<Uint8List> modelBytes(DownloadAsset model) =>
      WebModelCache.load(model);

  static Future<GalleryAssets> unpack() async => GalleryAssets(
    jsonDecode(await rootBundle.loadString('assets/manifest.json'))
        as Map<String, dynamic>,
  );
}

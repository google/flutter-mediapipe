import 'dart:convert';
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart'
    show DownloadAsset, ModelStore;

/// Samples unpacked to real files, because the native tasks read paths, and
/// the models `dart run mediapipe_core:bundle_models` bundled.
final class GalleryAssets {
  const GalleryAssets(this.directory, this.manifest);

  final Directory directory;
  final Map<String, dynamic> manifest;

  Set<String> get bundledTasks =>
      (manifest['tasks'] as List).cast<String>().toSet();

  String path(String name) => '${directory.path}/$name';

  File file(String name) => File(path(name));

  ImageProvider imageProvider(String name) => FileImage(file(name));

  static final _models = ModelStore();

  /// The bundled copy of [model] as a file, verified against its pin and
  /// cached once, exactly as a task created with `model:` finds it.
  static Future<String> modelPath(DownloadAsset model) async {
    if ((await _models.find(model))?.path case final path?) return path;
    throw StateError(
      '${Uri.parse(model.url).pathSegments.last} is not bundled in this '
      'build. Prepare the gallery again.',
    );
  }

  /// [model] as a verified file, downloaded into the model cache on first
  /// use: Decision Maker's models are too large to bundle.
  static Future<String> downloadedModelPath(DownloadAsset model) async =>
      (await _models.get(model)).path!;

  /// The bundled copy of [model], for demos that also accept a chosen or
  /// uploaded model's bytes.
  static Future<Uint8List> modelBytes(DownloadAsset model) async =>
      File(await modelPath(model)).readAsBytes();

  static Future<GalleryAssets>? _unpacked;

  /// Unpacks once per process; later calls share the first directory. The
  /// device suites ask once per test, and per-call copies once filled an
  /// iPhone until writes failed.
  static Future<GalleryAssets> unpack() async {
    try {
      return await (_unpacked ??= _unpack());
    } catch (_) {
      // A failed unpack is not kept, so a later call can try again.
      _unpacked = null;
      rethrow;
    }
  }

  static Future<GalleryAssets> _unpack() async {
    final directory = await Directory.systemTemp.createTemp(
      'mediapipe-gallery-',
    );
    final manifest =
        jsonDecode(await rootBundle.loadString('assets/manifest.json'))
            as Map<String, dynamic>;
    for (final name in (manifest['samples'] as List).cast<String>()) {
      final bytes = await rootBundle.load('assets/samples/$name');
      await File('${directory.path}/$name').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
    return GalleryAssets(directory, manifest);
  }
}

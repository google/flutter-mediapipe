import 'package:flutter/services.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart' show AudioModels;
import 'package:mediapipe_text/mediapipe_text.dart' show TextModels;
import 'package:mediapipe_vision/mediapipe_vision.dart';

/// The asset key of [model] in the gallery: `dart run
/// mediapipe_core:bundle_models` names each bundled model by its SHA-256.
String bundledModelAsset(DownloadAsset model) =>
    'assets/mediapipe/${model.sha256}';

/// The asset key of the pinned model Google publishes as [file], such as
/// `face_landmarker.task`.
String bundledModelFile(String file) => bundledModelAsset(
  _byFile[file] ?? (throw ArgumentError.value(file, 'file', 'Not pinned')),
);

/// The bytes of the bundled asset at [key].
Future<Uint8List> loadAssetBytes(String key) async {
  final data = await rootBundle.load(key);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// The bytes of the bundled pinned model Google publishes as [file].
Future<Uint8List> loadBundledModel(String file) =>
    loadAssetBytes(bundledModelFile(file));

final _byFile = {
  for (final model in [
    ...VisionModels.byName.values,
    ...TextModels.byName.values,
    ...AudioModels.byName.values,
  ])
    Uri.parse(model.url).pathSegments.last: model,
};

import 'exceptions.dart';
import 'download_asset.dart';

/// Where `dart run mediapipe_core:bundle_models` writes an app's models, and
/// where tasks created with `model:` look for them. The app declares this
/// folder under `flutter: assets:`.
const bundledModelsFolder = 'assets/mediapipe/';

/// The readable list of bundled models that the command writes beside them.
const bundledModelsManifest = 'manifest.json';

/// The asset key of a bundled model. Files are named by their SHA-256, like
/// the files an `asset_source` mirror serves.
String bundledModelKey(String sha256) => '$bundledModelsFolder$sha256';

/// The error for a model that the app neither bundles nor may download.
///
/// [registry] maps the names an app lists in
/// `hooks.user_defines.<family>.models` to their models, so the fix can name
/// the entry to add. [unreadable] explains why bundled models could not be
/// read at all, when that is the cause.
RuntimeUnavailableException modelNotBundled(
  DownloadAsset model, {
  String? family,
  Map<String, DownloadAsset> registry = const {},
  String? unreadable,
}) {
  final file = Uri.parse(model.url).pathSegments.last;
  final name = registry.entries
      .where((entry) => entry.value.sha256 == model.sha256)
      .map((entry) => entry.key)
      .firstOrNull;
  final entry = family != null && name != null
      ? 'Add $name to hooks.user_defines.$family.models in pubspec.yaml'
      : 'List the model under hooks.user_defines.<family>.models in '
            'pubspec.yaml';
  return RuntimeUnavailableException(
    'The model $file is not bundled with this app, and downloading models at '
    'run time is off.${unreadable == null ? '' : ' $unreadable'}',
    fix:
        '$entry, declare $bundledModelsFolder under flutter: assets:, and run '
        '`dart run mediapipe_core:bundle_models`. To download it at run time '
        'instead, set ModelStore.allowDownloads = true before creating the '
        'task.',
  );
}

/// The error for a bundled model whose bytes do not match its pin.
RuntimeUnavailableException bundledModelCorrupt(DownloadAsset model) =>
    RuntimeUnavailableException(
      'The bundled copy of ${Uri.parse(model.url).pathSegments.last} does not '
      'match its pinned SHA-256 ${model.sha256}.',
      fix:
          'Run `dart run mediapipe_core:bundle_models` again to replace it, '
          'then rebuild the app.',
    );

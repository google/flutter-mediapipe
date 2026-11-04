import 'download_asset.dart';
import 'model_bundle.dart';
import 'model_source.dart';
import 'model_store_io.dart'
    if (dart.library.js_interop) 'model_store_web.dart';
import 'bundled_model_stub.dart'
    if (dart.library.ui) 'bundled_model_flutter.dart'
    as bundle;

/// Resolve a pinned model to its verified copy: the cached one (a native file,
/// or bytes in the browser's Cache Storage), else the app's bundled copy, else
/// a download when [ModelStore.allowDownloads] is on.
///
/// [family] and [registry] (its `XxxModels.byName`) let the error for a
/// model that is not bundled name the pubspec entry to add.
Future<ModelSource> resolvePinnedModel(
  DownloadAsset model, {
  String? family,
  Map<String, DownloadAsset> registry = const {},
}) async {
  final store = ModelStore();
  final local = await store.find(model);
  if (local != null) return local;
  if (ModelStore.allowDownloads) return store.get(model);
  throw modelNotBundled(
    model,
    family: family,
    registry: registry,
    unreadable: bundle.bundledModelsUnreadable(),
  );
}

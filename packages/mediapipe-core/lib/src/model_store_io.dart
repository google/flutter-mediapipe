import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'download_asset.dart';
import 'model_bundle.dart';
import 'model_download_exception.dart';
import 'model_source.dart';
import 'verified_download.dart';
import 'bundled_model_stub.dart'
    if (dart.library.ui) 'bundled_model_flutter.dart'
    as bundle;
import 'support_directory_stub.dart'
    if (dart.library.ui) 'support_directory_flutter.dart'
    as support;

/// Verified models shared by every task family: the app's bundled copies,
/// cached in the application's persistent support directory, and downloads
/// when asked for. The same API in browsers, where models live in Cache
/// Storage and a [ModelSource] holds bytes instead of a path.
final class ModelStore {
  /// [cacheDirectory] replaces application support (useful for tests and
  /// Dart command-line tools); [source] is a SHA-named local directory or
  /// internal URL root; [client] replaces the default HTTP client.
  ModelStore({this.cacheDirectory, this.source, this.client});

  /// Whether tasks created with `model:` may download a model the app does
  /// not bundle. Off by default: `dart run mediapipe_core:bundle_models`
  /// bundles models at build time instead. Set it before creating tasks.
  ///
  /// Calling [get] or [prefetch] may download regardless of this setting.
  static bool allowDownloads = false;

  /// Stands in for the app's bundled models in tests.
  @visibleForTesting
  static Future<Uint8List?> Function(String sha256)? debugBundledModels;

  /// Stands in for application support when no [cacheDirectory] is given, in
  /// tests that run without Flutter.
  @visibleForTesting
  static String? debugCacheDirectory;

  /// Override for the persistent root, primarily for tests.
  final String? cacheDirectory;

  /// A SHA-named local directory or internal URL root.
  final String? source;

  /// HTTP client override, primarily for tests.
  final http.Client? client;
  final Map<String, Future<ModelSource?>> _finding = {};
  final Map<String, Future<ModelSource>> _inflight = {};

  Future<Directory> _root() async {
    final explicit = cacheDirectory ?? debugCacheDirectory;
    final root = explicit == null
        ? await support.modelsDirectory()
        : Directory(explicit);
    await root.create(recursive: true);
    if (explicit == null) await support.prepareModelsDirectory(root);
    return root;
  }

  /// The verified local copy of [model], without using the network: the
  /// cached file, else the app's bundled copy, which is copied into the cache
  /// once. Returns null when the app has neither.
  ///
  /// The file keeps the model's original name (MediaPipe can depend on its
  /// extension) inside a folder named by the start of its SHA-256.
  Future<ModelSource?> find(DownloadAsset model) =>
      _finding.putIfAbsent(model.sha256, () async {
        try {
          final root = await _root();
          final name = _folder(model);
          final file = await _withLock(
            root,
            name,
            () => _local(root, name, model),
          );
          return file == null ? null : ModelSource(path: file.path);
        } finally {
          // The entry is this very future, still completing; awaiting it would
          // never finish.
          unawaited(_finding.remove(model.sha256));
        }
      });

  /// Returns the verified file for [model]: cached, bundled or downloaded.
  /// Verifies every read and reuses valid bytes.
  Future<ModelSource> get(DownloadAsset model) =>
      _inflight.putIfAbsent(model.sha256, () async {
        try {
          return ModelSource(path: (await _get(model)).path);
        } finally {
          // The entry is this very future, still completing; awaiting it would
          // never finish.
          unawaited(_inflight.remove(model.sha256));
        }
      });

  // One locked section, so no other isolate or process stores the model
  // between the local lookup and the download.
  Future<File> _get(DownloadAsset model) async {
    final root = await _root();
    final name = _folder(model);
    return _withLock(root, name, () async {
      final local = await _local(root, name, model);
      if (local != null) return local;
      try {
        return await downloadVerified(
          model,
          _file(root, name, model),
          client: client,
          source: source,
        );
      } on DownloadException catch (error) {
        throw ModelDownloadException(error.failures, _networkHint(error));
      }
    });
  }

  // The cached copy, else the bundled copy written into the cache. The caller
  // holds the model's lock.
  Future<File?> _local(Directory root, String name, DownloadAsset model) async {
    final cached = await _cached(root, name, model);
    if (cached != null) return cached;
    final bytes = await (debugBundledModels ?? bundle.readBundledModel)(
      model.sha256,
    );
    if (bytes == null) return null;
    if (sha256.convert(bytes).toString() != model.sha256) {
      throw bundledModelCorrupt(model);
    }
    final file = _file(root, name, model);
    await file.parent.create(recursive: true);
    // Written beside the destination and renamed, so a crash never leaves a
    // partial model under the final name.
    final temporary = await file.parent.createTemp('.bundled-');
    try {
      final partial = File.fromUri(temporary.uri.resolve('asset'));
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
    } finally {
      await temporary.delete(recursive: true);
    }
    return file;
  }

  /// Prepares a model before task creation, for example on an onboarding page.
  Future<void> prefetch(DownloadAsset model) async {
    await get(model);
  }

  /// Removes every model this store holds, waiting for downloads in progress.
  Future<void> clear() async {
    final root = await _root();
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      await _withLock(root, name, () => entry.delete(recursive: true));
    }
  }

  // Sixteen hex digits keep paths short for Windows' 248-character folders.
  static String _folder(DownloadAsset model) => model.sha256.substring(0, 16);

  static File _file(Directory root, String name, DownloadAsset model) =>
      File.fromUri(
        root.uri.resolve('$name/${Uri.parse(model.url).pathSegments.last}'),
      );

  // A verified copy counts whichever pin (and file name) stored it.
  static Future<File?> _cached(
    Directory root,
    String name,
    DownloadAsset model,
  ) async {
    final folder = Directory.fromUri(root.uri.resolve('$name/'));
    if (!await folder.exists()) return null;
    await for (final entry in folder.list()) {
      if (entry is File &&
          (await sha256.bind(entry.openRead()).first).toString() ==
              model.sha256) {
        return entry;
      }
    }
    return null;
  }

  // Only a connection failure points at a missing platform permission.
  static String? _networkHint(DownloadException error) {
    final offline = error.failures.any(
      (failure) =>
          failure.reason.contains('SocketException') ||
          failure.reason.contains('ClientException'),
    );
    if (!offline) return null;
    if (Platform.isMacOS) {
      return 'A sandboxed macOS app needs the '
          'com.apple.security.network.client entitlement.';
    }
    if (Platform.isAndroid) {
      return 'Android needs the INTERNET permission in AndroidManifest.xml.';
    }
    return null;
  }

  static Future<DateTime?> _modified(File file) async {
    try {
      return await file.lastModified();
    } on FileSystemException {
      return null;
    }
  }

  // One claim file per model, so unrelated models never wait on each other,
  // held across isolates and processes.
  Future<T> _withLock<T>(
    Directory root,
    String name,
    Future<T> Function() body,
  ) async {
    final claim = File.fromUri(root.uri.resolve('$name.lock'));
    var missing = 0;
    while (true) {
      try {
        await claim.create(exclusive: true);
        break;
      } on FileSystemException catch (error, stack) {
        final modified = await _modified(claim);
        if (modified == null) {
          // The owner may have released the claim since the failed create,
          // and Windows refuses to create a file still being deleted. A
          // create that keeps failing with no claim present is a real error,
          // such as a folder the app cannot write.
          if (++missing == 20) Error.throwWithStackTrace(error, stack);
        } else {
          missing = 0;
          if (DateTime.now().difference(modified) >
              const Duration(minutes: 10)) {
            // A crashed process cannot remove its claim. Active owners
            // refresh the timestamp, including during a slow network transfer.
            try {
              await claim.delete();
            } on PathNotFoundException {
              // Another waiter removed it first.
            }
            continue;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    final heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(
        claim.setLastModified(DateTime.now()).catchError((Object _) {}),
      );
    });
    try {
      return await body();
    } finally {
      heartbeat.cancel();
      await claim.delete();
    }
  }
}

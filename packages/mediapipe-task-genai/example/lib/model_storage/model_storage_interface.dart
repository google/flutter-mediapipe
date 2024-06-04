import 'dart:async';

import 'package:example/models/models.dart';
import 'package:logging/logging.dart';

typedef ModelPaths = Map<LlmModel, String>;

final _log = Logger('ModelLocationStorage');

abstract class ModelStorageInterface {
  Future<void> setInitialModelLocations(
    ModelPaths initialModelLocations,
  ) async {
    for (final (model, location) in initialModelLocations.items) {
      _log.finer('${model.name} :: $location');
      if (location.isEmpty) continue;
      final uri = Uri.parse(location);

      late final String downloadDestination;
      switch (uri.scheme.startsWith('http')) {
        case (true):
          {
            downloadDestination = await urlToDownloadDestination(uri);
            if (await downloadExists(downloadDestination)) {
              setPathCache(model, downloadDestination);
            }
            setUriCache(model, uri);
          }
        case (false):
          {
            // If the location provided does not start with "http", it must be
            // something immediately accessible to the current runtime.
            downloadDestination = location;
            if (await downloadExists(downloadDestination)) {
              setPathCache(model, downloadDestination);
            } else {
              _log.warning(
                'Bad specification. Model for ${model.name} not found '
                'at at $location',
              );
            }
          }
      }
    }
  }

  /// Deletes the file at the given location.
  Future<void> delete(LlmModel model);

  /// Opens the resources to save an [LlmModel] binary and returns a stream to
  /// which bytes may be written.
  Future<StreamSink<List<int>>> create(String location);

  /// Marks a download initiated by [create] as successfully completed. Throws
  /// an exception if no such download is in progress.
  Future<void> close(String location);

  /// Terminates a download and deletes all progress. Throws an exception if no
  /// such download is in progress.
  Future<void> abort(String location);

  /// Determine to where in on-device storage this remote Url should be downloaded.
  Future<String> urlToDownloadDestination(Uri location);

  /// {@template downloadExists}
  /// Returns true if the model at the given file is completely downloaded, or
  /// false if it does not exist at all or is still downloading.
  /// {@endtemplate}
  Future<bool> downloadExists(String downloadLocation);

  /// {@template binarySize}
  /// Returns the size of the binary at the given on-device location. Throws an
  /// exception if the file does not exist, so before calling this method,
  /// verify that the model is downloaded with [downloadExists].
  /// {@endtemplate}
  int binarySize(String location);

  /// Returns the on-disk location of a downloaded model.
  String? pathFor(LlmModel model) => _pathCache[model];

  void clearPathCache(LlmModel model) => _pathCache.remove(model);

  /// Returns the remote location of a model.
  Uri? urlFor(LlmModel model) => _urlCache[model];

  /// On disk locations for the model. This could either have been supplied
  /// at compile-time via environment variable, or at runtime due to a web url
  /// location (also defined at compile-time) that was since been downloaded.
  final _pathCache = <LlmModel, String>{};

  /// Off-disk locations for models that could be downloaded to disk. Doing so
  /// will creating an entry in [_pathCache] for where the downloaded model
  /// resides on disk.
  ///
  /// This is stored (if known) even if the storage system believes the model is
  /// already downloaded, because the user could need to delete and redownload
  /// said model.
  final _urlCache = <LlmModel, Uri>{};

  void setUriCache(LlmModel model, Uri location) {
    _log.fine('Registered remote ${model.name} location at $location');
    _urlCache[model] = location;
  }

  void setPathCache(LlmModel model, String location) {
    _log.fine(
      'Detected downloaded binary for ${model.name} of size '
      '${binarySize(location)} bytes',
    );
    _pathCache[model] = location;
  }
}

extension ItemsMap<K, V> on Map<K, V> {
  Iterable<(K, V)> get items sync* {
    for (final K key in keys) {
      yield (key, this[key] as V);
    }
  }
}

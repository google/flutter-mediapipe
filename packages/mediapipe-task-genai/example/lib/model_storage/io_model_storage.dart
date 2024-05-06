import 'dart:async';
import 'dart:io';

import 'package:example/models/models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'model_storage_interface.dart';

class ModelStorage extends ModelStorageInterface {
  @override
  int binarySize(String location) {
    final file = File(location);
    if (!file.existsSync()) {
      throw Exception('Unexpectedly asked for binary size of non-existent '
          'file at $location');
    }
    return file.lengthSync();
  }

  @override
  Future<bool> downloadExists(String downloadLocation) =>
      File(downloadLocation).exists();

  @override
  Future<String> urlToDownloadDestination(Uri location) async => path.join(
        (await _getDownloadFolder()).absolute.path,
        location.pathSegments.last,
      );

  Directory? _downloadFolder;
  Future<Directory> _getDownloadFolder() async {
    _downloadFolder ??= await getApplicationCacheDirectory();
    return Future.value(_downloadFolder);
  }

  @override
  Future<void> abort(String location) async {
    if (!_downloadCache.containsKey(location)) {
      throw Exception('Abort called for location $location, which is not the '
          'site of an ongoing donwload.');
    }
    final file = File(location);
    if (await file.exists()) {
      await file.delete();
    }
    _downloadCache[location]!.close();
    _downloadCache.remove(location);
  }

  @override
  Future<void> close(String location) async {
    if (!_downloadCache.containsKey(location)) {
      throw Exception('Abort called for location $location, which is not the '
          'site of an ongoing donwload.');
    }
    _downloadCache[location]!.close();
    _downloadCache.remove(location);
  }

  final _downloadCache = <String, StreamSink<List<int>>>{};

  @override
  Future<StreamSink<List<int>>> create(String location) async {
    final file = File(location);
    if (await file.exists()) {
      throw Exception('Attempted to download on top of existing file at '
          '$location. Delete that file before proceeding.');
    }
    _downloadCache[location] = file.openWrite();
    return _downloadCache[location]!;
  }

  @override
  Future<void> delete(LlmModel model) async {
    final path = pathFor(model);
    if (path != null) {
      clearPathCache(model);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

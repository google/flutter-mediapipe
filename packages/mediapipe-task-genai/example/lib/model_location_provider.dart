import 'dart:async';
import 'dart:io';
import 'package:example/models/models.dart';
import 'package:example/model_storage/model_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _log = Logger('ModelLocationProvider');

/// Provides the locations of a given [LlmModel].
///
/// There are two constructors, but [fromEnvironment] is expected to be the most
/// useful assuming the Flutter application was build with the
/// `--dart-define=GEMMA_8B_GPU_PATH=<location>` flags, or similar, depending
/// on which models the developer and user intend to use.
///
/// Usage:
/// ```dart
/// final provider = ModelLocationProvider.fromEnvironment();
/// provider.getModelLocation(LlmModel.gemma8bGpu).then(
///   (String location) {
///      doSomethingWith(location);
///   },
/// );
/// final download = provider.getInProgressDownload(LlmModel.gemma8bGpu);
/// if (download != null) {
///   await for (final percent in download) {
///     showDownloadPercentage(percent);
///   }
/// }
/// ```
///
/// See also:
///  * [LlmModel], the enum which tracks each available LLM.
class ModelLocationProvider {
  ModelLocationProvider._({
    required ModelPaths modelLocations,
    required this.selectedModel,
  }) {
    storage = ModelStorage()
      ..setInitialModelLocations(modelLocations).then(
        (_) {
          _ready.complete();
        },
      );
  }
  factory ModelLocationProvider.fromEnvironment(LlmModel selectedModel) {
    return ModelLocationProvider._(
      modelLocations: ModelLocationProvider._getModelLocationsFromEnvironment(),
      selectedModel: selectedModel,
    );
  }

  LlmModel selectedModel;

  late final ModelStorageInterface storage;

  final _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  // Useful for quick development if there is any friction around passing
  // environment variables
  static const hardcodedLocations = <LlmModel, String>{
    LlmModel.gemma4bCpu:
        'https://storage.googleapis.com/random-storage-asdf/gemma/gemma-2b-it-cpu-int4.bin',
  };

  static ModelPaths _getModelLocationsFromEnvironment() {
    final locations = <LlmModel, String>{};
    for (final model in LlmModel.values) {
      String location = hardcodedLocations[model] ??
          Platform.environment[model.environmentVariableUriName] ??
          model.dartDefine;

      // `model.dartDefine` has an empty state of an empty string, not null,
      // which is why `location` is a `String` and not a `String?`
      if (location.isNotEmpty) {
        locations[model] = location;
      }
    }
    return locations;
  }

  /// {@macro downloadExists}
  Future<bool> downloadExists(String downloadLocation) =>
      storage.downloadExists(downloadLocation);

  Future<bool> downloadExistsForModel(LlmModel model) async {
    String? path = storage.pathFor(model);
    return path == null ? false : storage.downloadExists(path);
  }

  Future<void> delete(LlmModel model) async => await storage.delete(model);

  /// {@macro binarySize}
  int binarySize(String location) => storage.binarySize(location);

  /// Accepts a model and returns the size on disk for said model if it is
  /// already downloaded and fully available.
  int? binarySizeForModel(LlmModel model) {
    final location = pathFor(model);
    return location != null ? storage.binarySize(location) : null;
  }

  /// {@macro pathFor}
  String? pathFor(LlmModel model) => storage.pathFor(model);

  /// {@macro urlFor}
  Uri? urlFor(LlmModel model) => storage.urlFor(model);

  /// Storage for the controllers tied to in-progress downloads, each of which
  /// should emit download progress updates as a percentage.
  final _downloadControllers = <LlmModel, StreamController<int>>{};

  /// Asychronously returns the String for the location of a locally available
  /// copy of the requested model and an optional download progress stream if
  /// the model is downloading.
  Future<(Future<String>, Stream<int>?)> getModelLocation(
    LlmModel model,
  ) async {
    await ready;
    final path = storage.pathFor(model);
    if (path != null) {
      if (!await storage.downloadExists(path)) {
        throw Exception(
          'Location $path for $model was expected to have a file, but it is '
          'missing.',
        );
      }

      final binarySize = storage.binarySize(path);
      if (binarySize > 0) {
        _log.finer(
          'Returning already downloaded model for $model of '
          '$binarySize bytes',
        );
        return (Future.value(path), null);
      }
      _log.finer('Deleting existing $model of 0 bytes');
      storage.delete(model);
    }

    final url = storage.urlFor(model);
    if (url != null) {
      return _getOrStartDownload(model, url);
    }
    throw Exception(
      'ModelLocationProvider does not know where to find a '
      '${model.name} model, either on disk or elsewhere. Did you include a '
      'clause like `${model.environmentVariableUriName}=<location>` before '
      '`flutter run`? See the example README for more details.',
    );
  }

  /// Either initiates a fresh download or returns an ongoing download.
  Future<(Future<String>, Stream<int>?)> _getOrStartDownload(
    LlmModel model,
    Uri url,
  ) async {
    final downloadDestination = await storage.urlToDownloadDestination(url);

    // This is the way to figure out if the file is still being downloaded.
    // If there is a download controller for the model, we must await its
    // completion.
    if (!_downloadControllers.containsKey(model)) {
      return (
        Future.value(downloadDestination),
        await _downloadFile(model, url, downloadDestination)
      );
    }
    return (
      Future.value(downloadDestination),
      _downloadControllers[model]!.stream
    );
  }

  /// Downloads the file, creating and updating a stream with progress.
  ///
  /// This method does not return the location of the file, and in fact should
  /// not be called directly. Call [getModelLocation], which makes use of
  /// [_getOrStartDownload] if the file is not yet available on disk.
  Future<Stream<int>> _downloadFile(
    LlmModel model,
    Uri location,
    String downloadDestination,
  ) async {
    // Prepare a place for the file to be downloaded.
    if (await storage.downloadExists(downloadDestination)) {
      throw Exception('File exists at LLM model location in _downloadFile, '
          'which expects to only be called when said model location is empty. '
          'Unexpectedly occupied file location was ${location.path}');
    }
    final downloadSink = await storage.create(downloadDestination);

    // Setup the request itself and read preliminary headers.
    final request = http.Request('GET', location);
    final response = await request.send();
    final contentLength = int.parse(response.headers['content-length']!);
    _log.finer('File download: $contentLength bytes');
    final downloadCompleter = Completer<bool>();
    int downloadedBytes = 0;
    int lastPercentEmitted = 0;

    // Setup our reporting stream. Use a broadcast stream because calls to
    // `_getOrStartDownload` will need to resubscribe if the file is already
    // being downloaded.
    _downloadControllers[model] = StreamController<int>.broadcast();

    // Actually begin downloading
    response.stream.listen(
      (List<int> bytes) {
        downloadSink.add(bytes);
        downloadedBytes += bytes.length;
        int percent = ((downloadedBytes / contentLength) * 100).toInt();
        if ((percent > lastPercentEmitted)) {
          _log.finest('ModelLocationProvider :: $percent%');
          _downloadControllers[model]!.add(percent);
          lastPercentEmitted = percent;
        }
      },
      onDone: () => downloadCompleter.complete(true),
      onError: (error, stacktrace) {
        _log.shout('error: $error');
        _log.shout('stacktrace: $stacktrace');
        downloadCompleter.complete(false);
      },
    );
    downloadCompleter.future.then((downloadSuccessful) async {
      if (downloadSuccessful) {
        // Setting this value marks the model binary as fully downloaded.
        storage.setPathCache(model, downloadDestination);
        storage.close(downloadDestination);
      } else {
        // If the download did not complete, remove a partial download
        storage.abort(downloadDestination);
      }
      // Clean-up resources
      // Closing this controller is what signals to outside code that the file
      // download is complete.
      _downloadControllers[model]?.close();
      _downloadControllers.remove(model);
    });
    return _downloadControllers[model]!.stream;
  }
}

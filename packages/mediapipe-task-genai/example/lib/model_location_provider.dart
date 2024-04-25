import 'dart:async';
import 'dart:io';
import 'package:example/model_storage/model_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../llm_model.dart';

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
/// final (path, downloadStream) = provider.getModelLocation(LlmModel.gemma8bGpu);
/// if (downloadStream != null) {
///   // The file is being downloaded.
///   await for (final percent in downloadStream) {
///     print('$percent% done downloading')
///   }
/// }
/// if (await file.exists()) {
///   final options = LlmInferenceOptions(
///     modelPath: path,
///   );
/// } else {
///   // Download error!
/// }
/// ```
///
/// See also:
///  * [LlmModel], the enum which tracks each available LLM.
class ModelLocationProvider extends ChangeNotifier {
  ModelLocationProvider._({
    required ModelPaths modelLocations,
    required LlmModel selectedModel,
  }) : _selectedModel = selectedModel {
    storage = ModelStorage()
      ..setInitialModelLocations(modelLocations).then(
        (_) {
          _ready.complete();
          notifyListeners();
        },
      );
  }
  factory ModelLocationProvider.fromEnvironment(
    LlmModel selectedModel,
  ) {
    return ModelLocationProvider._(
      modelLocations: ModelLocationProvider._getModelLocationsFromEnvironment(),
      selectedModel: selectedModel,
    );
  }

  LlmModel _selectedModel;
  LlmModel get selectedModel => _selectedModel;
  set selectedModel(LlmModel value) {
    _selectedModel = value;
    notifyListeners();
  }

  late final ModelStorageInterface storage;

  final _ready = Completer<void>();

  static ModelPaths _getModelLocationsFromEnvironment() {
    final locations = <LlmModel, String>{};
    for (final model in LlmModel.values) {
      final location = Platform.environment[model.environmentVariableUriName];
      _log.info('${model.environmentVariableUriName} :: $location');
      if (location != null && location != '') {
        locations[model] = location;
      }
    }
    _log.info('Env locations: $locations');
    return locations;
  }

  /// {@macro downloadExists}
  Future<bool> downloadExists(String downloadLocation) =>
      storage.downloadExists(downloadLocation);

  Future<void> delete(LlmModel model) async {
    await storage.delete(model);
    notifyListeners();
  }

  /// {@macro binarySize}
  int binarySize(String location) => storage.binarySize(location);

  String? pathFor(LlmModel model) => storage.pathFor(model);
  Uri? urlFor(LlmModel model) => storage.urlFor(model);

  /// Storage for the controllers tied to in-progress downloads, each of which
  /// should emit download progress updates as a percentage.
  final _downloadControllers = <LlmModel, StreamController<double>>{};

  /// Returns a tuple of type a String and a nullable Stream of ints. If the
  /// stream is null, then the file is on disk and ready to go right now. If the
  /// stream is not null, the file is being downloaded and the Stream will emit
  /// values from 0 to 100 to represent the download completion percentage. Once
  /// the stream is exhausted, if the download was successful then the model's
  /// binary will be available at the given path.
  Future<String> getModelLocation(LlmModel model) async {
    _log.info('Requested model for $model');
    await _ready.future;
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
        _log.fine(
          'Returning already downloaded model for $model of '
          '$binarySize bytes',
        );
        return path;
      }
      _log.fine('Deleting existing $model of 0 bytes');
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

  /// Returns a stream for download progress for a model if said model is in the
  /// process of being downloaded. Otherwise, returns null.
  Stream<double>? getInProgressDownload(LlmModel model) =>
      _downloadControllers[model]?.stream;

  Future<String> _getOrStartDownload(LlmModel model, Uri url) async {
    final downloadDestination = await storage.urlToDownloadDestination(url);

    // This is the way to figure out if the file is still being downloaded.
    // Checking the file's existence could return true while it is still being
    // written.
    if (!_downloadControllers.containsKey(model)) {
      await _downloadFile(model, url, downloadDestination);
    }
    return downloadDestination;
  }

  Future<void> _downloadFile(
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
    _log.info('Beginning download of $model bin from ${location.toString()}');
    final downloadSink = await storage.create(downloadDestination);

    // Setup the request itself and read preliminary headers.
    final request = http.Request('GET', location);
    final response = await request.send();
    final contentLength = int.parse(response.headers['content-length']!);
    _log.finer('File download: $contentLength bytes');
    final downloadCompleter = Completer<bool>();
    int downloadedBytes = 0;
    double lastPercentEmitted = 0;

    // Setup our reporting stream.
    _downloadControllers[model] = StreamController<double>();

    // Actually begin downloading
    response.stream.listen(
      (List<int> bytes) {
        downloadSink.add(bytes);
        downloadedBytes += bytes.length;
        double percent = downloadedBytes / contentLength;
        // Update every tenth of a percent, or a thousand times in total
        if ((percent - lastPercentEmitted) > 0.001) {
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

      // Alert listeners that the download has completed.
      notifyListeners();
    });

    // Alert listeners that the download has started.
    notifyListeners();
  }
}

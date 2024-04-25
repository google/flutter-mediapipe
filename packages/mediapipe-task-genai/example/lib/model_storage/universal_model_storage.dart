import 'dart:async';

import 'package:example/llm_model.dart';

import 'model_storage_interface.dart';

class ModelStorage extends ModelStorageInterface {
  @override
  int binarySize(String location) => throw UnimplementedError();

  @override
  Future<bool> downloadExists(String downloadLocation) =>
      throw UnimplementedError();

  @override
  Future<String> urlToDownloadDestination(Uri location) async =>
      throw UnimplementedError();

  @override
  Future<void> abort(String location) => throw UnimplementedError();

  @override
  Future<void> close(String location) => throw UnimplementedError();

  @override
  Future<void> delete(LlmModel model) => throw UnimplementedError();

  @override
  Future<StreamSink<List<int>>> create(String location) =>
      throw UnimplementedError();
}

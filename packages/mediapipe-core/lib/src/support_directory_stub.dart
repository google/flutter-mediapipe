import 'dart:io';

/// A pure Dart caller must supply its persistent directory explicitly.
Future<Directory> modelsDirectory() => throw UnsupportedError(
  'A Flutter application is required to locate application support. In a '
  'Dart command-line tool, pass cacheDirectory to ModelStore, and give tasks '
  'modelPath instead of model.',
);

/// A caller-supplied directory needs no platform setup.
Future<void> prepareModelsDirectory(Directory directory) async {}

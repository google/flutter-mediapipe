import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:mediapipe_core/mediapipe_core.dart' show DownloadAsset;
import 'package:mediapipe_core/src/model_bundler.dart';
import 'package:yaml/yaml.dart';

const _usage = '''
Usage: dart run mediapipe_core:bundle_models [--check]

Run from the app's root. Downloads the models listed under
hooks.user_defines.<family>.models in pubspec.yaml, verifies each against its
pinned SHA-256, writes them into assets/mediapipe/ and removes any that are no
longer listed. With --check it only verifies that folder, for CI.''';

/// Bundles an app's models at build time. Tasks created with `model:` then
/// read them from the app instead of downloading them.
Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }
  if (arguments.any((argument) => argument != '--check')) {
    stderr.writeln(_usage);
    exit(64);
  }
  final check = arguments.contains('--check');
  final appRoot = Directory.current;
  final pubspecFile = File.fromUri(appRoot.uri.resolve('pubspec.yaml'));
  if (!await pubspecFile.exists()) {
    stderr.writeln('No pubspec.yaml here. Run this from the app\'s root.');
    exit(64);
  }
  final Object? pubspec;
  final Map<String, List<String>> listed;
  final String? source;
  try {
    pubspec = loadYaml(await pubspecFile.readAsString());
    listed = listedModels(pubspec);
    source = bundleSource(pubspec, appRoot);
  } on FormatException catch (error) {
    stderr.writeln('pubspec.yaml: ${error.message}');
    exit(1);
  }
  final needed = [
    for (final MapEntry(:key, :value) in listed.entries)
      if (value.isNotEmpty) key,
  ];
  final registries = needed.isEmpty
      ? <String, Map<String, DownloadAsset>>{}
      : await _registries(appRoot, needed);
  final result = await bundleModels(
    appRoot,
    [
      for (final family in needed)
        FamilyModels(family, listed[family]!, registries[family]!),
    ],
    declared: declaresBundledModels(pubspec),
    source: source,
    check: check,
  );
  result.lines.forEach(stdout.writeln);
  if (!result.ok) {
    for (final problem in result.problems) {
      stderr.writeln(problem);
    }
    exit(1);
  }
}

/// Reads each family's `XxxModels.byName` by running a generated program
/// with the app's packages, since mediapipe_core cannot import the families.
Future<Map<String, Map<String, DownloadAsset>>> _registries(
  Directory appRoot,
  List<String> families,
) async {
  for (final family in families) {
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:$family/models.dart'),
    );
    if (library == null) {
      stderr.writeln(
        'pubspec.yaml lists $family models, but the app does not depend on '
        '$family.',
      );
      exit(1);
    }
  }
  final program = File.fromUri(
    appRoot.uri.resolve(
      '.dart_tool/mediapipe_core/bundle_models_registry.dart',
    ),
  );
  await program.parent.create(recursive: true);
  await program.writeAsString(registryProgram(families));

  final reply = ReceivePort();
  final failure = ReceivePort();
  final exited = ReceivePort();
  final received = Completer<Map<Object?, Object?>>();
  reply.listen((message) {
    if (!received.isCompleted) received.complete(message as Map);
  });
  failure.listen((error) {
    if (!received.isCompleted) {
      received.completeError(StateError('${(error as List).first}'));
    }
  });
  exited.listen((_) {
    if (!received.isCompleted) {
      received.completeError(StateError('it exited without an answer'));
    }
  });
  try {
    await Isolate.spawnUri(
      program.uri,
      const [],
      reply.sendPort,
      packageConfig:
          await Isolate.packageConfig ??
          appRoot.uri.resolve('.dart_tool/package_config.json'),
      onError: failure.sendPort,
      onExit: exited.sendPort,
    );
    final message = await received.future;
    return {
      for (final MapEntry(:key, :value) in message.entries)
        key! as String: decodeRegistry(value! as Map),
    };
  } catch (error) {
    stderr.writeln(
      'Could not read the models of ${families.join(', ')}: $error',
    );
    exit(1);
  } finally {
    reply.close();
    failure.close();
    exited.close();
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:gallery_builder/models.dart';
import 'package:path/path.dart' as p;

import '../../../packages/mediapipe-task-vision/vision_tasks.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('target', mandatory: true)
    ..addOption('tasks', help: 'Comma-separated task subset.')
    ..addOption(
      'asset-source',
      help:
          "A directory holding Google's per-family MediaPipe libraries named by "
          'SHA-256, for offline builds; written to '
          'hooks.user_defines.mediapipe_core.asset_source.',
    )
    ..addOption(
      'modern-text-reference',
      help:
          'A directory of same-architecture references from '
          'tool/prepare_modern_text_reference.py to bundle for the generative '
          "text suite; the text package's checked-in macOS fixtures otherwise.",
    );
  late final ArgResults options;
  try {
    options = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  final target = options.option('target')!;
  final targets = galleryTargets(visionRuntimeTasks);
  final available = targets[target];
  if (available == null) {
    stderr.writeln(
      'Unknown target $target; choose one of ${targets.keys.join(', ')}.',
    );
    exitCode = 64;
    return;
  }
  final requested = options.option('tasks');
  final tasks = requested == null
      ? available
      : requested.split(',').map((task) => task.trim()).toSet();
  final unknown = tasks.difference(available);
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'Unavailable tasks for $target: ${unknown.toList()..sort()}',
    );
    exitCode = 64;
    return;
  }

  try {
    await _prepare(
      target,
      tasks.toList()..sort(),
      referenceDirectory: options.option('modern-text-reference'),
      assetSource: switch (options.option('asset-source')) {
        final path? => p.absolute(path),
        null => null,
      },
    );
  } on Object catch (error) {
    // Nothing needs cleaning up: a rerun keeps the models already verified
    // and fetches the rest.
    stderr.writeln('\nPreparation failed: $error');
    stderr.writeln('Nothing was built. Check the network and run it again.');
    exitCode = 1;
  }
}

Future<void> _prepare(
  String target,
  List<String> tasks, {
  String? referenceDirectory,
  String? assetSource,
}) async {
  final repo = _repositoryRoot();
  final gallery = p.join(repo, 'gallery');
  final samplesDirectory = Directory(p.join(gallery, 'assets/samples'));
  final referencesDirectory = Directory(
    p.join(gallery, 'assets/references/modern_text'),
  );
  // Models the gallery bundled itself before it used `bundle_models`.
  final legacyModels = Directory(p.join(gallery, 'assets/models'));
  if (await legacyModels.exists()) await legacyModels.delete(recursive: true);

  await _replaceDirectory(samplesDirectory);
  final sampleNames = <String>[];
  for (final entry in samples.entries) {
    if (!tasks.contains('audio_classifier') && entry.value.endsWith('.wav')) {
      continue;
    }
    if (!tasks.any(embedderSampleTasks.contains) &&
        embedderSamples.contains(entry.value)) {
      continue;
    }
    final source = File(p.join(repo, entry.key));
    if (!await source.exists()) {
      throw StateError('Required sample is missing: ${source.path}');
    }
    await source.copy(p.join(samplesDirectory.path, entry.value));
    sampleNames.add(entry.value);
  }
  sampleNames.sort();

  // Google's answers for the generative text suite, from the wheel of the
  // device's architecture, or the macOS fixtures. The browser suites compare
  // EmbeddingGemma with Google's JavaScript on the same page instead.
  if (await referencesDirectory.exists()) {
    await referencesDirectory.delete(recursive: true);
  }
  final modernText = target == 'web'
      ? <String>[]
      : tasks.where(modernTextTasks.contains).toList();
  if (modernText.isNotEmpty) {
    await referencesDirectory.create(recursive: true);
    for (final task in modernText) {
      final fixture = modernTextReferences[task]!;
      final source = File(
        referenceDirectory == null
            ? p.join(
                repo,
                'packages/mediapipe-task-text/test/fixtures',
                fixture,
                'official_reference.json',
              )
            : p.join(referenceDirectory, '$fixture.json'),
      );
      if (!await source.exists()) {
        throw StateError('Required reference is missing: ${source.path}');
      }
      await source.copy(p.join(referencesDirectory.path, '$fixture.json'));
    }
  }

  final manifest = <String, Object?>{
    'target': target,
    'tasks': tasks,
    'samples': sampleNames,
  };
  await File(
    p.join(gallery, 'assets/manifest.json'),
  ).writeAsString('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  await File(p.join(gallery, 'pubspec.yaml')).writeAsString(
    _pubspec(
      target,
      tasks,
      sampleNames,
      assetSource: assetSource,
      references: modernText.isNotEmpty,
    ),
  );

  // The gallery bundles its models as any app does: listed in pubspec, then
  // downloaded and verified by core's command.
  await _run('flutter', ['pub', 'get'], gallery);
  for (var attempt = 1; ; attempt++) {
    try {
      await _run('dart', ['run', 'mediapipe_core:bundle_models'], gallery);
      break;
    } on Object catch (error) {
      // A phone build should not fail on one dropped connection; a rerun
      // keeps the models already verified.
      if (attempt == 3) rethrow;
      stderr.writeln('  attempt $attempt failed ($error); retrying');
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
  }

  stdout.writeln('$target: ${tasks.length} task(s) bundled');
  for (final task in tasks) {
    stdout.writeln('  + $task');
  }
  final device = switch (target.split('/').first) {
    'web' => 'chrome',
    final desktop && ('macos' || 'linux' || 'windows') => desktop,
    _ => '<device-id>',
  };
  stdout.writeln('\nNext: cd gallery, then flutter run -d $device --release');
}

/// The checkout this script belongs to, found by the marker file at its
/// root, so the script works from any directory.
String _repositoryRoot() {
  final script = Platform.script;
  final starts = [
    if (script.scheme == 'file') p.dirname(script.toFilePath()),
    Directory.current.path,
  ];
  for (final start in starts) {
    var directory = p.normalize(p.absolute(start));
    while (true) {
      if (File(p.join(directory, '.flutter-mediapipe-root')).existsSync()) {
        return directory;
      }
      final parent = p.dirname(directory);
      if (parent == directory) break;
      directory = parent;
    }
  }
  throw StateError(
    'Run this from a flutter-mediapipe checkout; '
    'no .flutter-mediapipe-root above ${starts.join(' or ')}.',
  );
}

Future<void> _replaceDirectory(Directory directory) async {
  if (await directory.exists()) await directory.delete(recursive: true);
  await directory.create(recursive: true);
}

/// Runs [executable] in [directory], streaming its output, and throws when
/// it fails.
Future<void> _run(
  String executable,
  List<String> arguments,
  String directory,
) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: directory,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    throw StateError('$executable ${arguments.join(' ')} exited with $code');
  }
}

String _pubspec(
  String target,
  List<String> tasks,
  List<String> samples, {
  required String? assetSource,
  required bool references,
}) {
  // camera_desktop supplies the desktop preview and raw image streaming;
  // camera itself supplies the mobile and browser implementations.
  final camera = target.startsWith(RegExp('macos|linux|windows'))
      ? '  camera: ^0.12.1\n  camera_desktop: ^1.2.2'
      : '  camera: ^0.12.1';
  // Without one the hooks download the libraries, as an app's would.
  final core = assetSource == null
      ? ''
      : '    mediapipe_core:\n      asset_source: $assetSource\n';
  final entries = [
    '    - assets/mediapipe/',
    for (final name in samples) '    - assets/samples/$name',
    if (references) '    - assets/references/modern_text/',
  ].join('\n');
  final nativeTasks = target == 'web'
      ? tasks.where(webHostTestTasks.contains)
      : tasks.where((task) => !nonVisionTasks.contains(task));
  final defines = StringBuffer();
  for (final family in {for (final model in models.values) model.family}) {
    final names = {
      for (final task in tasks)
        if (models[task]!.family == family &&
            !downloadedModelTasks.contains(task))
          models[task]!.name,
    }.toList()..sort();
    defines.writeln('    $family:');
    if (family == 'mediapipe_vision') {
      defines.writeln('      tasks: [${nativeTasks.join(', ')}]');
    }
    defines.writeln('      models: [${names.join(', ')}]');
  }
  return '''# Generated by tool/gallery_builder for $target. Do not edit by hand:
# the task list is per-target and the build hook rejects unavailable tasks.
name: mediapipe_gallery
description: A portal to every MediaPipe task this repository supports.
publish_to: none
version: 0.1.0+1

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  mediapipe_vision:
    path: ../packages/mediapipe-task-vision
  mediapipe_text:
    path: ../packages/mediapipe-task-text
  mediapipe_audio:
    path: ../packages/mediapipe-task-audio
  mediapipe_decision:
    path: ../packages/mediapipe-task-decision
  mediapipe_retrieval:
    path: ../packages/mediapipe-task-retrieval
  web: ^1.1.1
  crypto: ^3.0.6
  file_selector: ^1.0.3
  image_picker: ^1.2.2
  video_frames:
    path: packages/video_frames
  record: ^7.1.1
  url_launcher: ^6.3.2
  lucide_icons_flutter: ^3.1.20
$camera

# The families depend on mediapipe_core from pub.dev; the gallery builds
# against this repository's copy.
dependency_overrides:
  mediapipe_core:
    path: ../packages/mediapipe-core

dev_dependencies:
  camera_platform_interface: ^2.13.1
  flutter_lints: ^6.0.0
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

hooks:
  user_defines:
$core$defines
flutter:
  uses-material-design: true
  fonts:
    - family: Arimo
      fonts:
        - asset: fonts/Arimo-400.ttf
        - asset: fonts/Arimo-600.ttf
          weight: 600
        - asset: fonts/Arimo-700.ttf
          weight: 700
  assets:
    - assets/manifest.json
$entries
''';
}

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;
import 'package:args/command_runner.dart';
import 'package:builder/extensions.dart';
import 'package:builder/repo_finder.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as path;
import 'package:process/process.dart';

/// Relative header paths (in both repositories)
final containers = 'mediapipe/tasks/c/components/containers';
final processors = 'mediapipe/tasks/c/components/processors';
final core = 'mediapipe/tasks/c/core';
final tc = 'mediapipe/tasks/c/text/text_classifier';
final te = 'mediapipe/tasks/c/text/text_embedder';

/// google/flutter-mediapipe package paths
final corePackage = 'packages/mediapipe-core/third_party';
final textPackage = 'packages/mediapipe-task-text/third_party';

/// First string is its relative location in both repositories,
/// Second string is its package location in `google/flutter-mediapipe`,
/// Third string is the file name
/// Fourth param is an optional function to modify the file
List<(String, String, String, Function(io.File)?)> headerPaths = [
  (containers, corePackage, 'category.h', null),
  (containers, corePackage, 'classification_result.h', null),
  (containers, corePackage, 'embedding_result.h', null),
  (core, corePackage, 'base_options.h', null),
  (processors, corePackage, 'classifier_options.h', null),
  (processors, corePackage, 'embedder_options.h', null),
  (tc, textPackage, 'text_classifier.h', relativeIncludes),
  (te, textPackage, 'text_embedder.h', relativeIncludes),
];

/// Command to copy all necessary C header files into this repository.
///
/// Pulls a list of hard-coded header files out of various destinations within
/// the google/mediapipe repository and places them in the same paths within
/// this repository. The only major change between their orientation within the
/// source repository (google/mediapipe) and their orientation here is that
/// shared header files are placed in `mediapipe-core` here, and no such
/// distinction exists in the source. This also implies rewriting the import
/// paths within these files to match, as their old relative positioning is
/// disrupted by the move.
class SyncHeadersCommand extends Command with RepoFinderMixin {
  @override
  String description = 'Syncs header files to google/flutter-mediapipe';
  @override
  String name = 'headers';

  SyncHeadersCommand() {
    argParser.addFlag(
      'overwrite',
      abbr: 'o',
      defaultsTo: true,
      help: 'If true, will overwrite existing header files '
          'at destination locations.',
    );
    addSourceOption(argParser);
    addVerboseOption(argParser);
  }

  @override
  Future<void> run() async {
    setUpLogging();
    final io.Directory flutterMediaPipeDirectory = findFlutterMediaPipeRoot();
    final io.Directory mediaPipeDirectory = findMediaPipeRoot(
      flutterMediaPipeDirectory,
      argResults!['source'],
    );

    final config = Options(
      allowOverwrite: argResults!['overwrite'],
      mediaPipeDir: mediaPipeDirectory,
      flutterMediaPipeDir: flutterMediaPipeDirectory,
    );

    await copyHeaders(config);
  }

  /// Central method that does the work of actually moving the files into the
  /// local repository and rewriting their relative import statements within
  /// the files themselves.
  Future<void> copyHeaders(Options config) async {
    final mgr = LocalProcessManager();
    for (final tup in headerPaths) {
      final headerFile = io.File(path.joinAll(
        [config.mediaPipeDir.absolute.path, tup.$1, tup.$3],
      ));
      if (!headerFile.existsSync()) {
        io.stderr.writeln(
          'Expected to find ${headerFile.path}, but '
          'file does not exist.',
        );
        io.exit(1);
      }
      final destinationPath = path.joinAll(
        [config.flutterMediaPipeDir.absolute.path, tup.$2, tup.$1, tup.$3],
      );
      final destinationFile = io.File(destinationPath);
      if (destinationFile.existsSync() && !config.allowOverwrite) {
        io.stdout.writeAll(
          [
            'Warning: Not overwriting existing file at $destinationPath\n',
            wrapWith('Skipping ${tup.$3}.\n', [cyan]),
          ],
        );
        continue;
      }

      // MediaPipe header files often come from deeply nested locations, and new
      // header files could require new folders. Thus, create any missing folders.
      ensureFolders(io.File(destinationPath));

      final process = await mgr.start(['cp', headerFile.path, destinationPath]);
      int processExitCode = await process.exitCode;
      if (processExitCode != 0) {
        final processStdErr = utf8.decoder.convert(
            (await process.stderr.toList())
                .fold<List<int>>([], (arr, el) => arr..addAll(el)));
        io.stderr.write(wrapWith(processStdErr, [red]));

        final processStdOut = utf8.decoder.convert(
            (await process.stdout.toList())
                .fold<List<int>>([], (arr, el) => arr..addAll(el)));
        io.stderr.write(wrapWith(processStdOut, [red]));
        io.exit(processExitCode);
      } else {
        io.stderr.writeln(wrapWith('Copied ${tup.$3}', [green]));
      }

      // Call the final modification function, if supplied
      if (tup.$4 != null) {
        tup.$4!.call(destinationFile);
      }
    }
  }
}

class Options {
  const Options({
    required this.allowOverwrite,
    required this.mediaPipeDir,
    required this.flutterMediaPipeDir,
  });

  final bool allowOverwrite;
  final io.Directory mediaPipeDir;
  final io.Directory flutterMediaPipeDir;
}

void relativeIncludes(io.File file) {
  assert(file.path.endsWith('.h'));
  Map<String, String> rewrites = {
    containers: '../../../../../../../mediapipe-core/third_party/$containers',
    processors: '../../../../../../../mediapipe-core/third_party/$processors',
    core: '../../../../../../../mediapipe-core/third_party/$core',
  };
  String contents = file.readAsStringSync();

  for (final rewrite in rewrites.entries) {
    contents = contents.replaceAll(rewrite.key, rewrite.value);
  }
  file.writeAsStringSync(contents);
  io.stdout.writeln(
    wrapWith(
      'Made includes relative for '
      '${lastChunk(file.absolute.path, delimiter: io.Platform.pathSeparator)}',
      [green],
    ),
  );
}

// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:path/path.dart' as path;

import 'extensions.dart';
import 'repo_finder.dart';

final _log = Logger('SDKsFinder');

/// Structure of flattened build locations suitable for JSON serialization.
/// Format is:
///   {
///     <os>: {
///       <sdk>: {
///         <arch>: <fullpath>,
///         ...
///       },
///     },
///     ...
///   }
typedef _FlatResults = Map<String, Map<String, Map<String, String>>>;

/// Container for the three flavors of MediaPipe tasks.
enum MediaPipeSdk {
  genai,
  libaudio,
  libtext,
  libvision;

  String toPackageDir() => switch (this) {
        MediaPipeSdk.genai => 'mediapipe-task-genai',
        MediaPipeSdk.libaudio => 'mediapipe-task-audio',
        MediaPipeSdk.libtext => 'mediapipe-task-text',
        MediaPipeSdk.libvision => 'mediapipe-task-vision',
      };

  String binaryName() => switch (this) {
        MediaPipeSdk.genai => 'libllm_inference_engine',
        MediaPipeSdk.libaudio => MediaPipeSdk.libaudio.name,
        MediaPipeSdk.libtext => MediaPipeSdk.libtext.name,
        MediaPipeSdk.libvision => MediaPipeSdk.libvision.name,
      };
}

/// Scans the GCS buckets where MediaPipe SDKs are stored, identifies the latest
/// builds for each supported build target, and writes the output to a
/// designated file.
///
/// [SdksFinderCommand] depends on `gsutil` and a Google-corp account that has
/// permissions to read the necessary buckets, so the idea is to run this
/// command on Googlers' work machines whenever MediaPipe rebuilds SDKs. The
/// manual nature of this command is suboptimal, but there is no precedent for
/// fully automating this portion of the MediaPipe release process, so this
/// command helps by automating a portion of the task.
///
/// The cache-busting mechanism of Flutter's native assets feature is a hash
/// of the contents of any build dependencies. The output files of this command
/// are included in the build dependencies (as specified by the contents of each
/// package's `build.dart` file), so if this command generates new SDK locations
/// in those files, Flutter's CLI will have a cache miss, will re-run
/// `build.dart` during the build phase, and in turn will download the newest
/// versions of the MediaPipe SDKs onto the developer's machine.
///
/// Operationally, [SdksFinderCommand]'s implementation involves orchestrating
/// one [_OsFinder] instance for each supported [OS] value, which in turn
/// identifies the correct build that has been uploaded to GCS by MediaPipe
/// release machinery.
///
/// Usage:
/// ```sh
///   $ cd path/to/flutter-mediapipe
///   $ dart tool/builder/bin/main.dart sdks [-v]
/// ```
class SdksFinderCommand extends Command with RepoFinderMixin {
  SdksFinderCommand() {
    addVerboseOption(argParser);
  }
  @override
  String description =
      'Updates MediaPipe SDK manifest files for the current build target.';

  @override
  String name = 'sdks';

  static const _gcsPrefix = 'https://storage.googleapis.com';

  /// Google Storage bucket which houses all MediaPipe SDK uploads.
  static const _bucketName = 'mediapipe-nightly-public/prod/mediapipe';

  final _finders = <_OsFinder>[
    _OsFinder(OS.android),
    _OsFinder(OS.macOS),
    _OsFinder(OS.iOS),
    // TODO: Add other values as their support is ready
  ];

  @override
  Future<void> run() async {
    setUpLogging();
    _checkGsUtil();
    final results = _SdkLocations();

    for (final finder in _finders) {
      await for (final sdkLocation in finder.find()) {
        results.add(sdkLocation);
      }
    }
    for (final MediaPipeSdk sdk in MediaPipeSdk.values) {
      _log.info('Saving locations for ${sdk.name}');
      _writeResults(sdk, results.toMap(sdk));
    }
  }

  void _writeResults(MediaPipeSdk sdk, _FlatResults results) {
    final file = _getOutputFile(sdk);
    _log.fine('Writing data to "${file.absolute.path}"');
    var encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync('''// Generated file. Do not manually edit.
// Used by the flutter toolchain (via build.dart) during compilation of any
// Flutter app using this package.
final Map<String, Map<String, Map<String, String>>> sdkDownloadUrls = ${encoder.convert(results).replaceAll('"', "'")};
''');
    io.Process.start('dart', ['format', file.absolute.path]);
  }

  File _getOutputFile(MediaPipeSdk sdk) {
    return File(
      path.joinAll([
        findFlutterMediaPipeRoot().absolute.path,
        'packages/${sdk.toPackageDir()}',
        'sdk_downloads.dart',
      ]),
    );
  }

  void _checkGsUtil() async {
    if (!io.Platform.isMacOS && !io.Platform.isLinux) {
      // `which` is not available on Windows, so allow the command to attempt
      // to run on Windows
      // TODO: possibly add Windows-specific support
      return;
    }
    final process = await Process.start('which', ['gsutil']);
    final exitCode = await process.exitCode;
    final List<String> processStdOut = await process.processedStdOut;
    if (exitCode != 0) {
      stderr.writeln(
        wrapWith(
          'Warning: Unexpected exit code $exitCode checking for gsutil. Output:'
          '${processStdOut.join('\n')}',
          [yellow],
        ),
      );
      // Not exiting here, since this could be a false-negative.
    }
    if (processStdOut.isEmpty) {
      stderr.writeln(
        wrapWith(
          'gsutil command not found. Visit: '
          'https://cloud.google.com/storage/docs/gsutil_install',
          [red],
        ),
      );
      exit(1);
    }
  }
}

/// Main workhorse of the SdksFinderCommand. Navigates folders in GCS to find
/// the location of the latest builds for each [MediaPipeSdk] / [Architecture]
/// combination for the given [OS].
///
/// Usage:
/// ```dart
///   final macOsFinder = _OsFinder(OS.macOS);
///   await for (final _SdkLocation sdkLoc in macOsFinder.find()) {
///     doSomethingWithLocation(sdkLoc);
///   }
/// ```
class _OsFinder {
  _OsFinder(this.os);

  /// OS-specific upload directories located immediately inside
  /// [SdksFinderCommand._bucketName].
  static const _gcsFolderPaths = <OS, String?>{
    OS.android: 'gcp_ubuntu_flutter',
    OS.iOS: 'macos_flutter',
    OS.macOS: 'macos_flutter',
  };

  /// File extensions for OS-specific SDKs.
  static const _sdkExtensions = <OS, String?>{
    OS.android: 'so',
    OS.iOS: 'dylib',
    OS.macOS: 'dylib',
  };

  /// Folders for specific [Target] values, where a Target is an OS/architecture
  /// combination.
  static const targetFolders = <OS, Map<String, Architecture>>{
    OS.android: {
      'android_arm64': Architecture.arm64,
    },
    OS.iOS: {
      'ios_arm64': Architecture.arm64,
    },
    OS.macOS: {
      'darwin_arm64': Architecture.arm64,
      'darwin_x86_64': Architecture.x64,
    },
  };

  final OS os;

  String get folderPath => '${_gcsFolderPaths[os]!}/release';
  String get extension => _sdkExtensions[os]!;

  /// Scans the appropriate GCS location for all build Ids for the given OS and
  /// returns the highest integer found.
  ///
  /// Returns a future iterator, instead of a stream, because it's one async
  /// gap up front and then we want synchronous iterator behavior across the
  /// build ids.
  Iterable<int> _getBuildNumbers(List<String> paths) sync* {
    List<int> buildIds = [];
    for (final folder in paths) {
      late int buildId;
      try {
        // Grab last chunk, since we're looking for a folder of the
        // structure: `.../release/:int/`
        buildId = int.parse(lastChunk(folder));
      } catch (e) {
        // Probably the `{id}_$folder$` directory
        continue;
      }
      buildIds.add(buildId);
    }

    buildIds.sort();
    for (final buildId in buildIds.reversed) {
      yield buildId;
    }
  }

  /// Extracts the date within a build directory, which is where the final
  /// artifacts can be found.
  ///
  /// Usage:
  /// ```dart
  /// final path = await _getDateOfBuildNumber('.../gcp_ubuntu_flutter/release/', 17);
  /// print(path);
  /// >>> ".../gcp_ubuntu_flutter/release/17/20231212-090734/"
  /// ```
  Future<String> _getDateOfBuildNumber(String path) async {
    final foldersInBuild = await _gsUtil(path);
    if (foldersInBuild.isEmpty || foldersInBuild.length > 2) {
      final paths =
          foldersInBuild.map<String>((path) => ' • $path').toList().join('\n');
      _log.warning('Unexpectedly found ${foldersInBuild.length} entries inside '
          'build folder: $path. Expected 1 or 2, of formats "/[date]/" and '
          'optionally "/[date]_\$folder\$". Found:\n\n$paths\n');
    }
    for (final folderPath in foldersInBuild) {
      if (folderPath.endsWith('/')) {
        final buildDateFolderPath = lastChunk(folderPath);
        _log.fine('$folderPath :: $buildDateFolderPath');
        return buildDateFolderPath;
      }
    }
    throw Exception(
      'Unexpected structure of build folder: "$path". Did not find match.',
    );
  }

  /// Receives a path like `".../[os_folder]/release/[build_number]/[date]/"`
  /// and yields all matching architecture folders within.
  Stream<String> _getArchitectectures(String path) async* {
    final pathsWithinBuild = <String>[];
    final expectedFolders = targetFolders[os]!.keys.toSet();
    for (final pathWithinBuild in await _gsUtil(path)) {
      pathsWithinBuild.add(lastChunk(pathWithinBuild));
      final maybeArchitecture = lastChunk(pathWithinBuild);
      if (targetFolders[os]!.containsKey(maybeArchitecture)) {
        expectedFolders.remove(maybeArchitecture);
        yield maybeArchitecture;
      }
    }
    if (expectedFolders.isNotEmpty) {
      _log.warning(
        'Did not find all expected folders in "$path".\n '
        'Expected to find ${targetFolders[os]!.keys.toSet()}.\n '
        'Did not find $expectedFolders.\n '
        'Folders in path were: $pathsWithinBuild.',
      );
    }
  }

  /// Combines the path, file name, and extension into the final, complete path.
  /// Additionally, checks whether that file actually exists and returns the
  /// String value if it does, or `null` if it does not.
  Future<String?> _getAndCheckFullPath(String path, MediaPipeSdk sdk) async {
    final pathToCheck = '$path/${sdk.binaryName()}.${_sdkExtensions[os]!}';
    final output = await _gsUtil(pathToCheck);
    if (output.isEmpty) {
      return null;
    }
    return pathToCheck;
  }

  Stream<_SdkLocation> find() async* {
    _log.info('Finding SDKs for $os');
    String path = folderPath;
    for (final buildNumber in _getBuildNumbers(await _gsUtil(path))) {
      path = '$folderPath/$buildNumber';
      _log.finest('$os :: build number :: $path');
      final buildDate = await _getDateOfBuildNumber(path);
      path = '$path/$buildDate';
      _log.finest('$os :: date :: $path');

      bool buildNumberFoundSdks = false;
      await for (final String archPath in _getArchitectectures(path)) {
        String pathWithArch = '$path/$archPath';
        _log.finest('$os :: $archPath :: $pathWithArch');
        for (final sdk in MediaPipeSdk.values) {
          final maybeFinalPath = await _getAndCheckFullPath(pathWithArch, sdk);
          _log.finest('$os :: maybeFinalPath :: $maybeFinalPath');
          if (maybeFinalPath != null) {
            _log.info('Found "$maybeFinalPath"');
            buildNumberFoundSdks = true;
            yield _SdkLocation(
              os: os,
              arch: targetFolders[os]![archPath]!,
              sdk: sdk,
              fullPath: '${SdksFinderCommand._gcsPrefix}/'
                  '${SdksFinderCommand._bucketName}/$maybeFinalPath',
            );
          }
        }
      }
      if (buildNumberFoundSdks) {
        return;
      }
    }
  }
}

// Runs `gsutil ls` against the path, optionally with the `-r` flag.
Future<List<String>> _gsUtil(String path, {bool recursive = false}) async {
  assert(
    !path.startsWith('http'),
    'gsutil requires URIs with the "gs" scheme, which this function will add.',
  );
  final cmd = [
    'ls',
    if (recursive) '-r',
    'gs://${SdksFinderCommand._bucketName}/$path',
  ];
  _log.finest('Running: `gsutil ${cmd.join(' ')}`');
  final process = await Process.start('gsutil', cmd);
  final exitCode = await process.exitCode;
  if (exitCode > 1) {
    // Exit codes of 1 appear when `gsutil` checks for a file that does not
    // exist, which for our purposes does not constitute an actual error, and is
    // handled later when `process.processedStdOut` is empty.
    stderr.writeln(
      wrapWith(
        'Warning: Unexpected exit code $exitCode running '
        '`gsutil ${cmd.join(' ')}`. Output: '
        '${(await process.processedStdOut).join('\n')}',
        [red],
      ),
    );
    exit(exitCode);
  }
  final processStdout = await process.processedStdOut;
  final filtered = (processStdout).where((String line) => line != '').toList();
  return filtered;
}

/// Simple container for the location of a specific MediaPipe SDK in GCS.
class _SdkLocation {
  _SdkLocation({
    required this.os,
    required this.arch,
    required this.sdk,
    required this.fullPath,
  });
  final OS os;
  final Architecture arch;
  final MediaPipeSdk sdk;
  final String fullPath;

  @override
  String toString() => '_SdkLocation(os: $os, arch: $arch, sdk: $sdk, '
      'fullPath: $fullPath)';
}

/// Container for multiple [_SdkLocation] objects with support for quickly
/// extracting all records for a given MediaPipe task (audio, vision, or text).
class _SdkLocations {
  final Map<MediaPipeSdk, List<_SdkLocation>> _locations = {};

  void add(_SdkLocation loc) {
    _locations.setDefault(loc.sdk, <_SdkLocation>[]);
    _locations[loc.sdk]!.add(loc);
  }

  _FlatResults toMap(MediaPipeSdk sdk) {
    if (!_locations.containsKey(sdk)) return {};

    final _FlatResults results = <String, Map<String, Map<String, String>>>{};
    for (_SdkLocation loc in _locations[sdk]!) {
      results.setDefault(loc.os.toString(), <String, Map<String, String>>{});
      results[loc.os.toString()]!.setDefault(
        loc.sdk.binaryName(),
        <String, String>{},
      );
      results[loc.os.toString()]![loc.sdk.binaryName()]![loc.arch.toString()] =
          loc.fullPath;
    }

    return results;
  }
}

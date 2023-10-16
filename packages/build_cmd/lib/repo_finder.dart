import 'dart:io' as io;
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:io/ansi.dart';

/// Mixin to help [Command] subclasses locate both `google/mediapipe` and
/// the root of `google/flutter-mediapipe` (this repository).
///
/// The primary methods are [findFlutterMediaPipeRoot] and [findMediaPipeRoot].
///
/// By default, the root for `google/flutter-mediapipe` is determined by the
/// firest ancestor directory which contains a `.flutter-mediapipe-root` file
/// (whose contents are irrelevant), and the root of `google/mediapipe` is
/// expected to be a sibling of that. However, the `--source` flag can overwrite
/// this expectation and specify an absolute path where to find `google/mediapipe`.
///
/// Note that it is not possible to override the method of locating the root of
/// `google/flutter-mediapipe`.
mixin RepoFinderMixin on Command {
  /// Name of the file which, when found, indicates the root of this repository.
  static String sentinelFileName = '.flutter-mediapipe-root';

  void addSourceOption(ArgParser argParser) {
    argParser.addOption(
      'source',
      abbr: 's',
      help: 'The location of google/mediapipe. Defaults to being '
          'adjacent to google/flutter-mediapipe.',
    );
  }

  /// Looks upward for the root of the `google/mediapipe` repository. This assumes
  /// the `dart build` command is executed from within said repository. If it is
  /// not executed from within, then this searching algorithm will reach the root
  /// of the file system, log the error, and exit.
  io.Directory findFlutterMediaPipeRoot() {
    final placesChecked = <io.Directory>[];
    io.Directory dir = io.Directory(path.current);
    while (true) {
      if (_isFlutterMediaPipeRoot(dir)) {
        return dir;
      }
      placesChecked.add(dir);
      dir = dir.parent;
      if (dir.parent.path == dir.path) {
        io.stderr.writeln(
          wrapWith(
            'Failed to find google/flutter-mediapipe root directory. '
            'Did you execute this command from within the repository?\n'
            'Looked in:',
            [red],
          ),
        );
        io.stderr.writeln(
          wrapWith(
            placesChecked
                .map<String>((dir) => ' - ${dir.absolute.path}')
                .toList()
                .join('\n'),
            [red],
          ),
        );
        io.exit(1);
      }
    }
  }

  /// Finds the `google/mediapipe` checkout where artifacts built in this
  /// repository should be sourced. By default, this command assumes the two
  /// repositories are siblings on the file system, but the `--source` flag
  /// allows for this assumption to be overridden.
  io.Directory findMediaPipeRoot(
    io.Directory flutterMediaPipeDir,
    String? source,
  ) {
    final mediaPipeDirectory = io.Directory(
      source ??
          path.joinAll([flutterMediaPipeDir.parent.absolute.path, 'mediapipe']),
    );

    if (!mediaPipeDirectory.existsSync()) {
      io.stderr.writeln(
        'Could not find ${mediaPipeDirectory.absolute.path}. '
        'Folder does not exist.',
      );
      io.exit(1);
    }
    return mediaPipeDirectory;
  }

  /// Looks for the sentinel file of this repository's root directory. This allows
  /// the `dart build` command to be run from various locations within the
  /// `google/mediapipe` repository and still correctly set paths for all of its
  /// operations.
  bool _isFlutterMediaPipeRoot(io.Directory dir) {
    return io.File(
      path.joinAll(
        [dir.absolute.path, sentinelFileName],
      ),
    ).existsSync();
  }
}

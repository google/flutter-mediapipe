import 'dart:io' as io;
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:io/ansi.dart';

mixin RepoFinderMixin on Command {
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
    io.Directory dir = io.Directory(path.current);
    while (true) {
      if (_isFlutterMediaPipeRoot(dir)) {
        return dir;
      }
      dir = dir.parent;
      if (dir.parent.path == dir.path) {
        io.stderr.writeln(
          wrapWith(
            'Failed to find google/mediapipe root directory. '
            'Did you execute this command from within the repository?',
            [red],
          ),
        );
        io.exit(1);
      }
    }
  }

  /// Finds the `google/mediapipe` checkout where artifacts built in this
  /// repository should be sourced. By default, this command assumes the two
  /// repositories are siblings on the file system, but the `--origin` flag
  /// allows for this assumption to be overridden.
  io.Directory findMediaPipeRoot(
    io.Directory flutterMediaPipeDir,
    String? origin,
  ) {
    final flutterMediaPipeDirectory = io.Directory(
      origin ??
          path.joinAll([
            flutterMediaPipeDir.parent.absolute.path,
            'mediapipe',
          ]),
    );

    if (!flutterMediaPipeDirectory.existsSync()) {
      io.stderr.writeln(
        'Could not find ${flutterMediaPipeDirectory.absolute.path}. '
        'Folder does not exist.',
      );
      io.exit(1);
    }
    return flutterMediaPipeDirectory;
  }
}

/// Looks for the sentinel file of this repository's root directory. This allows
/// the `dart build` command to be run from various locations within the
/// `google/mediapipe` repository and still correctly set paths for all of its
/// operations.
bool _isFlutterMediaPipeRoot(io.Directory dir) {
  return io.File(
    path.joinAll(
      [dir.absolute.path, '.flutter-mediapipe-root'],
    ),
  ).existsSync();
}

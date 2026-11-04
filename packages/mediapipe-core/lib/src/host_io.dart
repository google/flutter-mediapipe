/// What the family packages need from the host when they call Google's C API.
library;

import 'dart:io';

/// Google's `MpHostSystem` value for this process, the way its Python API
/// fills `BaseOptions.host_system` from `platform.system()`.
int get mpHostSystem => Platform.isLinux
    ? 1
    : Platform.isMacOS
    ? 2
    : Platform.isWindows
    ? 3
    : Platform.isIOS
    ? 4
    : Platform.isAndroid
    ? 5
    : 0;

/// Google's `BaseOptions.host_version` for this process, written like a
/// browser's user agent: the OS and its version, then Dart's and Flutter's,
/// for example `iOS 26.4 / Dart 3.13.4 / Flutter 3.47.5`. Flutter's version
/// comes from the define the Flutter tool sets for `FlutterVersion`, so a
/// program the tool did not build leaves it out.
final String mpHostVersion = [
  _operatingSystem,
  'Dart ${Platform.version.split(' ').first}',
  if (_flutterVersion != null) 'Flutter $_flutterVersion',
].join(' / ');

/// The version `FlutterVersion.version` reads, from the same define.
const _flutterVersion = bool.hasEnvironment('FLUTTER_VERSION')
    ? String.fromEnvironment('FLUTTER_VERSION')
    : null;

/// The OS as a user agent names it, with the version Dart reports, plus the
/// build on Windows, whose 10 and 11 both report 10.0. Android goes without:
/// Dart reports its kernel's version.
String get _operatingSystem {
  final name = switch (Platform.operatingSystem) {
    'macos' => 'macOS',
    'ios' => 'iOS',
    'android' => 'Android',
    'linux' => 'Linux',
    'windows' => 'Windows',
    final other => other,
  };
  final version = RegExp(
    r'(\d+(?:\.\d+)+)(?: \(Build (\d+)\))?',
  ).firstMatch(Platform.operatingSystemVersion);
  if (Platform.isAndroid || version == null) return name;
  final build = version[2];
  return '$name ${version[1]}${build == null ? '' : '.$build'}';
}

/// [path] as Google's C API should receive it: absolute on Android, whose
/// MediaPipe resource resolver reads a relative path as an asset inside the
/// app's APK rather than as a file.
String nativeModelPath(String path) =>
    Platform.isAndroid ? File(path).absolute.path : path;

/// Google's Linux runtime links EGL and OpenGL ES even for CPU inference, so a
/// system without them cannot load it at all. Names the packages to install.
StateError? missingLinuxGraphicsLibraries(String loaderError) {
  if (!Platform.isLinux ||
      !(loaderError.contains('libEGL') || loaderError.contains('libGLES'))) {
    return null;
  }
  return StateError(
    'Google\'s official MediaPipe Linux runtime needs the system EGL and '
    'OpenGL ES libraries (libEGL.so.1, libGLESv2.so.2), even for CPU '
    'inference. Install them, for example with '
    '`sudo apt-get install libegl1 libgles2` on Debian or Ubuntu. '
    'Loader error: $loaderError',
  );
}

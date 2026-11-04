import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'task_capabilities.dart';

Future<TaskPlatform>? _platform;

/// Inspect the process ABI and OS once, without loading a MediaPipe library.
Future<TaskPlatform> currentTaskPlatform() => _platform ??= _readPlatform();

Future<TaskPlatform> _readPlatform() async {
  String? version;
  if (Platform.isMacOS || Platform.isIOS) {
    // Read the product version without spawning a process (including in a
    // sandboxed Flutter app, and on iOS where spawning is not allowed at all).
    // Darwin kernel versions are not product versions, and both systems answer
    // the same sysctl. A capability table that carries a minimum iOS version
    // fails closed when the version is unknown, so leaving iOS out here would
    // hide every task the package does support on a phone.
    try {
      version = using((arena) {
        final sysctl = DynamicLibrary.process()
            .lookupFunction<
              Int32 Function(
                Pointer<Char>,
                Pointer<Void>,
                Pointer<Size>,
                Pointer<Void>,
                Size,
              ),
              int Function(
                Pointer<Char>,
                Pointer<Void>,
                Pointer<Size>,
                Pointer<Void>,
                int,
              )
            >('sysctlbyname');
        final key = 'kern.osproductversion'
            .toNativeUtf8(allocator: arena)
            .cast<Char>();
        final size = arena<Size>();
        if (sysctl(key, nullptr, size, nullptr, 0) != 0 ||
            size.value < 1 ||
            size.value > 256) {
          return null;
        }
        final buffer = arena<Uint8>(size.value);
        if (sysctl(key, buffer.cast(), size, nullptr, 0) != 0) return null;
        final value = buffer.cast<Utf8>().toDartString(length: size.value - 1);
        return RegExp(r'^\d+(\.\d+)*$').hasMatch(value) ? value : null;
      });
    } on ArgumentError {
      // Unknown version is reported as unavailable, not assumed compatible.
    }
  }
  return TaskPlatform(
    operatingSystem: Platform.operatingSystem,
    architecture: Abi.current().toString().split('_').last,
    version: version,
    gpu: await readTaskPlatformGpu(),
    simulator: _iosSimulator,
  );
}

/// Whether this process runs in Apple's iOS Simulator. The simulator starts
/// every app with its `SIMULATOR_*` environment; a device never sets it.
final bool _iosSimulator = Platform.isIOS && _hasEnvironment('SIMULATOR_UDID');

/// Asks libc directly: Dart's `Platform.environment` is always empty on iOS.
bool _hasEnvironment(String name) => using((arena) {
  final getenv = DynamicLibrary.process()
      .lookupFunction<
        Pointer<Char> Function(Pointer<Char>),
        Pointer<Char> Function(Pointer<Char>)
      >('getenv');
  return getenv(name.toNativeUtf8(allocator: arena).cast()) != nullptr;
});

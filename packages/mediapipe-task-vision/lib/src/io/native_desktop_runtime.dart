import 'dart:ffi';
import 'dart:io';

import 'package:mediapipe_core/platform_interface.dart'
    show missingLinuxGraphicsLibraries;

@Native<Void Function(Pointer<Char>)>(
  symbol: 'MpErrorFree',
  assetId: 'package:mediapipe_vision/mediapipe.dylib',
)
external void _errorFree(Pointer<Char> error);

/// Loads Google's vision library on Linux and Windows before a task uses it,
/// so a library that cannot load (on Linux, usually missing EGL or GLES)
/// fails with the fix rather than a bare symbol lookup error.
void loadOfficialDesktopRuntime() {
  if (Platform.isLinux || Platform.isWindows) {
    final Pointer<NativeFunction<Void Function(Pointer<Char>)>> errorFree;
    try {
      errorFree = Native.addressOf(_errorFree);
    } on Object catch (error) {
      throw missingLinuxGraphicsLibraries('$error') ?? error;
    }
    if (errorFree == nullptr) {
      throw StateError(
        'The official desktop runtime has no error-free export.',
      );
    }
  }
}

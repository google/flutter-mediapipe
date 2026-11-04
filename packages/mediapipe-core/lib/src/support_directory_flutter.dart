import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

/// Application support folder reserved for MediaPipe models.
Future<Directory> modelsDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory.fromUri(support.uri.resolve('mediapipe/models/'));
}

/// Excludes downloaded iOS models from iCloud backup.
///
/// Calls CoreFoundation directly (`kCFURLIsExcludedFromBackupKey`, the C side
/// of Foundation's `isExcludedFromBackup`), which every iOS process loads, so
/// core needs no native plugin and apps no CocoaPods.
Future<void> prepareModelsDirectory(Directory directory) async {
  if (Platform.isIOS) _excludeFromBackup(directory.path);
}

typedef _CFURLCreateNative =
    Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, IntPtr, Bool);
typedef _CFURLCreate =
    Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, int, bool);
typedef _CFURLSetPropertyNative =
    Bool Function(
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Void>>,
    );
typedef _CFURLSetProperty =
    bool Function(
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<Void>>,
    );
typedef _CFReleaseNative = Void Function(Pointer<Void>);
typedef _CFRelease = void Function(Pointer<Void>);

void _excludeFromBackup(String path) {
  final cf = DynamicLibrary.process();
  final create = cf.lookupFunction<_CFURLCreateNative, _CFURLCreate>(
    'CFURLCreateFromFileSystemRepresentation',
  );
  final setProperty = cf
      .lookupFunction<_CFURLSetPropertyNative, _CFURLSetProperty>(
        'CFURLSetResourcePropertyForKey',
      );
  final release = cf.lookupFunction<_CFReleaseNative, _CFRelease>('CFRelease');
  // Both are CFTypeRef globals: the symbol holds the pointer.
  final key = cf.lookup<Pointer<Void>>('kCFURLIsExcludedFromBackupKey').value;
  final yes = cf.lookup<Pointer<Void>>('kCFBooleanTrue').value;
  using((arena) {
    final bytes = path.toNativeUtf8(allocator: arena);
    final url = create(nullptr, bytes.cast<Uint8>(), bytes.length, true);
    if (url == nullptr) {
      throw FileSystemException('Cannot address the model folder', path);
    }
    try {
      if (!setProperty(url, key, yes, nullptr)) {
        throw FileSystemException(
          'Cannot exclude the model folder from iCloud backup',
          path,
        );
      }
    } finally {
      release(url);
    }
  });
}

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'ios_backup_stub.dart'
    if (dart.library.ffi) 'ios_backup_ffi.dart'
    as backup;

/// Application support folder reserved for MediaPipe models.
Future<Directory> modelsDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory.fromUri(support.uri.resolve('mediapipe/models/'));
}

/// Excludes downloaded iOS models from iCloud backup.
Future<void> prepareModelsDirectory(Directory directory) async {
  if (Platform.isIOS) backup.excludeFromBackup(directory.path);
}

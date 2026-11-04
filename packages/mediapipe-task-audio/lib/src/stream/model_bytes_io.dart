import 'dart:io';
import 'dart:typed_data';

/// The model file at [path], which Google's task has just opened, read for
/// its audio input.
Future<Uint8List> readModelBytes(String path) => File(path).readAsBytes();

import 'dart:typed_data';

/// Only browsers stream bundled models; elsewhere `ModelStore` reads them.
Future<Uint8List?> streamBundledModel(
  String sha256,
  void Function(int received) onReceived,
) async => null;

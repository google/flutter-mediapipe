import 'dart:typed_data';

/// Where a verified model is: a file [path] on native platforms, [bytes] in
/// browsers. What `ModelStore` returns and a task reads.
final class ModelSource {
  /// Exactly one of [path] or [bytes] is set.
  const ModelSource({this.path, this.bytes});

  /// The model file on native platforms, null in browsers.
  final String? path;

  /// The model's verified bytes in browsers, null on native platforms.
  final Uint8List? bytes;

  @override
  String toString() =>
      'ModelSource(${path ?? '${bytes!.length} bytes in memory'})';
}

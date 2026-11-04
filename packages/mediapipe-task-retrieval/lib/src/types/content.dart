/// The parts a record or a query is made of: text, an encoded image, or
/// audio samples, embedded into one space by Universal Embedder.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

/// One part of a multimodal record or query.
sealed class ContentPart {
  const ContentPart();

  /// The part as both runtimes take it: a `kind` and its data.
  Map<String, Object?> toJson();
}

/// A piece of text.
@immutable
final class TextPart extends ContentPart {
  /// [text] must be non-empty and, as Google's C API reads strings, free of
  /// NUL characters.
  TextPart(this.text) {
    if (text.isEmpty || text.contains('\u0000')) {
      throw ArgumentError.value(
        text,
        'text',
        'Must be non-empty, without NUL.',
      );
    }
  }

  /// The text.
  final String text;

  @override
  Map<String, Object?> toJson() => {'kind': 'text', 'text': text};

  @override
  String toString() => 'TextPart($text)';
}

/// An image, as the encoded bytes of a JPEG or PNG, or on Android, iOS,
/// macOS, Linux and Windows as a [filePath] Google's runtime decodes itself.
/// Browsers take bytes only.
@immutable
final class ImagePart extends ContentPart {
  /// Supply [imageBytes], [filePath] or both.
  ImagePart({Uint8List? imageBytes, this.filePath})
    : imageBytes = imageBytes == null
          ? null
          : Uint8List.fromList(imageBytes).asUnmodifiableView() {
    checkSource(imageBytes?.length, filePath, 'imageBytes', 'filePath');
  }

  /// The encoded image, or null for a file the runtime reads.
  final Uint8List? imageBytes;

  /// The image file's path, or null for bytes.
  final String? filePath;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'image',
    'imageBytes': imageBytes,
    'filePath': filePath,
  };

  @override
  String toString() =>
      'ImagePart(${imageBytes == null ? filePath : '${imageBytes!.length} bytes'})';
}

/// Audio, as mono PCM float samples at the rate the model expects, or on
/// Android, iOS, macOS, Linux and Windows as an [audioPath] to a WAV file
/// Google's runtime decodes itself. Browsers take samples only.
@immutable
final class AudioPart extends ContentPart {
  /// Supply [audioData], [audioPath] or both.
  AudioPart({Float32List? audioData, this.audioPath})
    : audioData = audioData == null
          ? null
          : Float32List.fromList(audioData).asUnmodifiableView() {
    checkSource(audioData?.length, audioPath, 'audioData', 'audioPath');
  }

  /// The samples, or null for a file the runtime reads.
  final Float32List? audioData;

  /// The WAV file's path, or null for samples.
  final String? audioPath;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'audio',
    'audioData': audioData,
    'audioPath': audioPath,
  };

  @override
  String toString() =>
      'AudioPart(${audioData == null ? audioPath : '${audioData!.length} samples'})';
}

/// Rejects a part with neither data nor a usable path.
@internal
void checkSource(int? length, String? path, String data, String pathName) {
  final hasData = length != null && length > 0;
  final hasPath = path != null && path.isNotEmpty && !path.contains('\u0000');
  if (!hasData && !hasPath) {
    throw ArgumentError('Supply $data or $pathName.');
  }
  if (path != null && (path.isEmpty || path.contains('\u0000'))) {
    throw ArgumentError.value(path, pathName, 'Invalid path');
  }
}

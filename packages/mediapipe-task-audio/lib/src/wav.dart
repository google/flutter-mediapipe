import 'dart:typed_data';

import 'types.dart';

/// Reads a RIFF WAVE file of 16-bit PCM or 32-bit float samples, as recorded
/// by most tools and as MediaPipe's own sample clips are.
AudioData decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  String tag(int at) => String.fromCharCodes(bytes, at, at + 4);
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const FormatException('Not a WAV file.');
  }
  int? format, channels, rate, bits;
  for (var at = 12; at + 8 <= bytes.length;) {
    final size = data.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (tag(at) == 'fmt ') {
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      rate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (tag(at) == 'data') {
      if (format == null) throw const FormatException('WAV data before fmt.');
      final end = (body + size).clamp(body, bytes.length);
      final samples = switch ((format, bits)) {
        (1, 16) => Float32List.fromList([
          for (var i = body; i + 1 < end; i += 2)
            data.getInt16(i, Endian.little) / 32768,
        ]),
        (3, 32) => Float32List.fromList([
          for (var i = body; i + 3 < end; i += 4)
            data.getFloat32(i, Endian.little),
        ]),
        _ => throw FormatException(
          'Unsupported WAV encoding: format $format, $bits bits. '
          'Use 16-bit PCM or 32-bit float.',
        ),
      };
      return AudioData(
        samples: samples,
        sampleRate: rate!.toDouble(),
        channels: channels!,
      );
    }
    at = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV file has no data chunk.');
}

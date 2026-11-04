import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:record/record.dart';

/// Starts a microphone at [sampleRate] Hz, one channel, and returns its
/// 16-bit little-endian PCM in chunks of any size; cancelling the
/// subscription stops it. The recorder by default; tests and the browser
/// tests' page (`?microphone=sample`) play the speech sample instead.
typedef MicrophoneSource = Future<Stream<Uint8List>> Function(int sampleRate);

/// The device's microphone, through the `record` plugin.
Future<Stream<Uint8List>> recorderMicrophone(int sampleRate) async {
  final recorder = AudioRecorder();
  try {
    if (!await recorder.hasPermission()) {
      throw StateError('Microphone access was not granted.');
    }
    final stream = await recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
    late final StreamController<Uint8List> chunks;
    StreamSubscription<Uint8List>? subscription;
    chunks = StreamController<Uint8List>(
      onListen: () => subscription = stream.listen(
        chunks.add,
        onError: chunks.addError,
        onDone: chunks.close,
      ),
      onCancel: () async {
        await subscription?.cancel();
        await recorder.stop();
        await recorder.dispose();
      },
    );
    return chunks.stream;
  } catch (_) {
    await recorder.dispose();
    rethrow;
  }
}

/// A microphone that plays the 16 kHz speech sample once, about 100 ms of it
/// every 100 ms, in chunks of an odd number of bytes so that every chunk
/// splits a sample, as a recorder's may.
MicrophoneSource sampleMicrophone({
  String asset = 'assets/samples/speech_16000_hz_mono.wav',
}) => (sampleRate) async {
  final data = await rootBundle.load(asset);
  final clip = decodeWav(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  if (clip.sampleRate != sampleRate || clip.channels != 1) {
    throw StateError('$asset is not $sampleRate Hz mono.');
  }
  final pcm = ByteData(clip.samples.length * 2);
  for (var i = 0; i < clip.samples.length; i++) {
    pcm.setInt16(i * 2, (clip.samples[i] * 32768).round(), Endian.little);
  }
  final bytes = pcm.buffer.asUint8List();
  final chunk = sampleRate ~/ 10 * 2 + 1;
  var at = 0;
  return Stream<Uint8List>.periodic(const Duration(milliseconds: 100), (_) {
    final end = (at + chunk).clamp(0, bytes.length);
    final next = Uint8List.sublistView(bytes, at, end);
    at = end;
    return next;
  }).takeWhile((next) => next.isNotEmpty);
};

/// Turns a recorder's 16-bit little-endian PCM chunks into stream blocks,
/// each stamped with its first sample's time counted from the samples sent,
/// so the timestamps agree with the audio and Google's stream logs no
/// warning about them.
final class PcmBlocks {
  /// Blocks of one channel at [sampleRate] Hz.
  PcmBlocks(this.sampleRate);

  /// The rate the recorder records at.
  final int sampleRate;

  final _held = BytesBuilder();
  var _sent = 0;

  /// The block [chunk] completes and its timestamp, or null while the bytes
  /// held back are too few. A chunk may end inside a sample, whose first byte
  /// waits for the next chunk, and a block must advance the millisecond, or
  /// the next block's timestamp would repeat its own.
  (AudioData, int)? add(Uint8List chunk) {
    _held.add(chunk);
    final frames = _held.length ~/ 2;
    final start = _sent * 1000 ~/ sampleRate;
    if (frames == 0 || (_sent + frames) * 1000 ~/ sampleRate == start) {
      return null;
    }
    final bytes = _held.takeBytes();
    final pcm = ByteData.sublistView(bytes);
    final samples = Float32List(frames);
    for (var i = 0; i < frames; i++) {
      samples[i] = pcm.getInt16(i * 2, Endian.little) / 32768;
    }
    if (bytes.length.isOdd) _held.addByte(bytes.last);
    _sent += frames;
    return (
      AudioData(samples: samples, sampleRate: sampleRate.toDouble()),
      start,
    );
  }

  /// Where the next block's audio starts, in milliseconds of the stream.
  int get sentMilliseconds => _sent * 1000 ~/ sampleRate;
}

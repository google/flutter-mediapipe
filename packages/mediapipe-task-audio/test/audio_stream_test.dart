import 'dart:io';
import 'dart:typed_data';

import 'package:mediapipe_audio/src/stream/model_specs.dart';
import 'package:test/test.dart';

import 'support/stream_suite.dart';

/// The audio stream's contract on a fake backend
/// (support/stream_suite.dart), and the model reader on the pinned YAMNet.
void main() {
  streamSuite();

  test('YAMNet\'s input is read as Google\'s readers read it', () {
    final model = File('models/yamnet.tflite').readAsBytesSync();
    // What Google's generated readers in its 1.0.0 wheel report for this
    // file: a [15600] input, 16 kHz and one channel in its AudioProperties.
    final specs = AudioModelSpecs.read(model);
    expect(
      specs,
      const AudioModelSpecs(
        windowSamples: 15600,
        sampleRate: 16000,
        channels: 1,
      ),
    );
    expect(specs.stepMicroseconds, 975000);
    expect(
      () => AudioModelSpecs.read(Uint8List.sublistView(model, 0, 4000000)),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'the model is truncated',
        ),
      ),
    );
  });
}

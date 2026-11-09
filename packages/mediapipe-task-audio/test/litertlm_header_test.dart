import 'dart:io';
import 'dart:typed_data';

import 'package:mediapipe_audio/src/litertlm_header.dart';
import 'package:test/test.dart';

// Each fixture is a bundle's bytes up to its header's end (Apache 2.0):
// kokoro_int8_gpu_fp16.litertlm from huggingface.co/litert-community/Kokoro-82M
// at 33ad69fec6c4d9eb10a547aaf9a8c63e7c446a56 (SHA-256 1ef178b1...eac52), and
// phonon_int8.litertlm as AudioModels.phonon pins it.
Uint8List _fixture(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

void main() {
  final kokoro = _fixture('kokoro_int8_gpu_fp16_header.bin');
  final phonon = _fixture('phonon_int8_header.bin');

  test('reads where each header ends', () {
    expect(litertlmHeaderEnd(kokoro), kokoro.length);
    expect(litertlmHeaderEnd(phonon), phonon.length);
  });

  test("Kokoro's bundle marks a section for the GPU, Phonon's none", () {
    expect(litertlmHasGpuSection(kokoro), isTrue);
    expect(litertlmHasGpuSection(phonon), isFalse);
  });

  test('anything else is not a LiteRT-LM header', () {
    expect(litertlmHeaderEnd(Uint8List(8)), isNull);
    expect(litertlmHasGpuSection(Uint8List(64)), isNull);
    // A TFLite file, as YAMNet's.
    expect(
      litertlmHasGpuSection(
        Uint8List.fromList([...List.filled(4, 0), ...'TFL3'.codeUnits]),
      ),
      isNull,
    );
    // Cut short of its end, or with a later major version.
    expect(
      litertlmHasGpuSection(Uint8List.sublistView(kokoro, 0, 4096)),
      isNull,
    );
    expect(litertlmHasGpuSection(Uint8List.fromList(kokoro)..[8] = 2), isNull);
    // Offsets that point outside the header.
    final broken = Uint8List.fromList(kokoro)
      ..setAll(32, [0xff, 0xff, 0xff, 0x0f]);
    expect(litertlmHasGpuSection(broken), isNull);
  });
}

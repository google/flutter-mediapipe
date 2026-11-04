import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_audio/src/third_party/mediapipe/audio_classifier_bindings.dart'
    as abi;
import 'package:test/test.dart';
import 'support/same_host_reference.dart';

const _fixtures = 'test/fixtures';
const _model = 'models/yamnet.tflite';

/// The same runtime, model and samples as Google's reference, so scores agree
/// to rounding (the reference rounds to six places).
const _scoreDelta = 1e-5;

void main() {
  final reference = loadSameHostReference(
    'official_reference.json',
    prefix: '',
    cases: 'clips',
  );
  final clips = reference['clips'] as Map<String, dynamic>;

  setUpAll(() {
    expect(
      sha256.convert(File(_model).readAsBytesSync()).toString(),
      AudioModels.yamnet.sha256,
    );
    expect(reference['model_sha256'], AudioModels.yamnet.sha256);
  });

  for (final MapEntry(key: clip, value: expected) in clips.entries) {
    test('$clip matches the official result, chunk by chunk', () async {
      final task = await AudioClassifier.create(
        AudioClassifierOptions(modelPath: _model, maxResults: 3),
      );
      addTearDown(task.dispose);
      final audio = decodeWav(File('$_fixtures/$clip').readAsBytesSync());
      final chunks = await task.classify(audio);
      final want = (expected as List).cast<Map<String, dynamic>>();
      expect(chunks, hasLength(want.length));
      for (final (i, chunk) in chunks.indexed) {
        expect(chunk.timestampMilliseconds, want[i]['timestamp_ms']);
        final categories = chunk.classifications.single.categories;
        final top = {
          for (final [name as String, score as num]
              in (want[i]['top'] as List).cast<List>())
            name: score.toDouble(),
        };
        // Google's scores for these names, in its order; categories with
        // equal scores may come in either order.
        expect(categories.map((c) => c.categoryName).toSet(), top.keys.toSet());
        for (final category in categories) {
          expect(
            category.score,
            closeTo(top[category.categoryName]!, _scoreDelta),
          );
        }
        final scores = [for (final c in categories) c.score];
        expect(
          scores,
          orderedEquals([...scores]..sort((x, y) => y.compareTo(x))),
        );
      }
    });
  }

  test('model bytes, repeated calls and max results agree', () async {
    final task = await AudioClassifier.create(
      AudioClassifierOptions(
        modelBytes: File(_model).readAsBytesSync(),
        maxResults: 1,
      ),
    );
    addTearDown(task.dispose);
    final audio = decodeWav(
      File('$_fixtures/speech_16000_hz_mono.wav').readAsBytesSync(),
    );
    final [first, second] = await Future.wait([
      task.classify(audio),
      task.classify(audio),
    ]);
    expect(
      first.first.classifications.single.categories.single.categoryName,
      'Speech',
    );
    expect(
      second.first.classifications.single.categories.single.score,
      first.first.classifications.single.categories.single.score,
    );
  });

  test('score threshold drops weak categories', () async {
    final task = await AudioClassifier.create(
      AudioClassifierOptions(modelPath: _model, scoreThreshold: 0.5),
    );
    addTearDown(task.dispose);
    final chunks = await task.classify(
      decodeWav(File('$_fixtures/speech_16000_hz_mono.wav').readAsBytesSync()),
    );
    for (final chunk in chunks) {
      for (final category in chunk.classifications.single.categories) {
        expect(category.score, greaterThanOrEqualTo(0.5));
      }
    }
  });

  test('errors come back as exceptions, and disposal is final', () async {
    await expectLater(
      AudioClassifier.create(
        AudioClassifierOptions(modelBytes: Uint8List.fromList([1, 2, 3])),
      ),
      throwsA(isA<TaskException>()),
    );
    final task = await AudioClassifier.create(
      AudioClassifierOptions(modelPath: _model),
    );
    final closing = task.dispose();
    expect(identical(closing, task.dispose()), isTrue);
    await closing;
    await expectLater(
      task.classify(AudioData(samples: Float32List(16000), sampleRate: 16000)),
      throwsStateError,
    );
    expect(task.delegate, Delegate.cpu);
    expect(task.runningMode, AudioRunningMode.audioClips);
    expect(() => decodeWav(Uint8List(4)), throwsFormatException);
  });

  test('options are checked the same way on every platform', () async {
    expect(
      () => AudioClassifierOptions(modelPath: _model, maxResults: 0),
      throwsArgumentError,
    );
    expect(
      () => AudioClassifierOptions(
        modelPath: _model,
        categoryAllowlist: ['Speech'],
        categoryDenylist: ['Music'],
      ),
      throwsArgumentError,
    );
    // A stream task opens, and is a stream task only.
    final stream = await AudioClassifier.create(
      AudioClassifierOptions(
        modelPath: _model,
        runningMode: AudioRunningMode.audioStream,
      ),
    );
    expect(stream.runningMode, AudioRunningMode.audioStream);
    await expectLater(
      stream.classify(
        AudioData(samples: Float32List(16000), sampleRate: 16000),
      ),
      throwsStateError,
    );
    await stream.dispose();
    await expectLater(
      AudioClassifier.create(
        AudioClassifierOptions(modelPath: _model, delegate: Delegate.gpu),
      ),
      throwsA(isA<RuntimeUnavailableException>()),
    );
  });

  test('the allowlist keeps only the named categories', () async {
    final task = await AudioClassifier.create(
      AudioClassifierOptions(modelPath: _model, categoryAllowlist: ['Music']),
    );
    addTearDown(task.dispose);
    final chunks = await task.classify(
      decodeWav(File('$_fixtures/speech_16000_hz_mono.wav').readAsBytesSync()),
    );
    for (final chunk in chunks) {
      expect(
        chunk.classifications.single.categories.map((c) => c.categoryName),
        everyElement('Music'),
      );
    }
  });

  test('struct layouts match the official 1.0.1 ctypes', () {
    expect(sizeOf<abi.MpBaseOptions>(), 72);
    expect(sizeOf<abi.MpClassifierOptions>(), 48);
    expect(sizeOf<abi.MpAudioClassifierOptions>(), 136);
    expect(sizeOf<abi.MpAudioData>(), 32);
    expect(sizeOf<abi.MpClassificationResult>(), 32);
    expect(sizeOf<abi.MpClassifications>(), 24);
    expect(sizeOf<abi.MpCategory>(), 24);
    expect(sizeOf<abi.MpAudioClassifierResult>(), 16);
  });
}

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_audio/platform_interface.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_text/platform_interface.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';
import 'support/device_log.dart';

/// Text Classifier, Text Embedder, Language Detector and Audio Classifier
/// through Google's mobile text and audio libraries, against Google's own
/// outputs for the same inputs (the packages' checked-in references, from the
/// macOS wheel).
/// Another runtime build on another CPU, so scores get a cross-runtime bound.
/// Runs on the Android emulator and iOS simulator in CI, and on phones.
const _scoreBound = 2e-3;

/// YAMNet reports scores in 1/256 steps; allow two steps.
const _audioBound = 2 / 256;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('official SDK text tasks match Google\'s references', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(Platform.isAndroid || Platform.isIOS, isTrue);
      expect(
        textTaskBackendFactory,
        isNull,
        reason:
            "Android and iOS run Google's C library through FFI, not a plugin backend",
      );
      final bert = await loadAssetBytes(
        bundledModelFile('bert_classifier.tflite'),
      );
      for (final (text, options, expected)
          in <
            (
              String,
              ({int maxResults, double scoreThreshold, List<String> denylist}),
              List<(String, double)>,
            )
          >[
            (
              'Hello, world!',
              (maxResults: -1, scoreThreshold: 0.0, denylist: const <String>[]),
              [('positive', 0.992178), ('negative', 0.007822)],
            ),
            (
              'This was a terrible movie. I hated every minute.',
              (maxResults: -1, scoreThreshold: 0.0, denylist: const <String>[]),
              [('negative', 0.998278), ('positive', 0.001722)],
            ),
            (
              'Hello, world!',
              (maxResults: 1, scoreThreshold: 0.0, denylist: const <String>[]),
              [('positive', 0.992178)],
            ),
            (
              'Hello, world!',
              (
                maxResults: -1,
                scoreThreshold: 0.0,
                denylist: const ['positive'],
              ),
              [('negative', 0.007822)],
            ),
            (
              'Hello, world!',
              (maxResults: -1, scoreThreshold: 1.0, denylist: const <String>[]),
              [],
            ),
          ]) {
        final task = await TextClassifier.create(
          TextClassifierOptions(
            modelBytes: bert,
            maxResults: options.maxResults,
            scoreThreshold: options.scoreThreshold,
            categoryDenylist: options.denylist,
          ),
        );
        try {
          final result = await task.classify(text);
          final categories = result.classifications.single.categories.toList();
          expect(categories.map((c) => c.categoryName), [
            for (final e in expected) e.$1,
          ]);
          for (final (i, (_, score)) in expected.indexed) {
            expect(categories[i].score, closeTo(score, _scoreBound));
          }
          expect(result.classifications.single.headName, 'probability');
        } finally {
          await task.dispose();
        }
      }
      // Requests run in order; none is accepted after disposal.
      final ordered = await TextClassifier.create(
        TextClassifierOptions(modelBytes: bert),
      );
      final results = await Future.wait([
        ordered.classify('Hello, world!'),
        ordered.classify('This was a terrible movie. I hated every minute.'),
      ]);
      expect(
        results.map(
          (r) => r.classifications.single.categories.first.categoryName,
        ),
        ['positive', 'negative'],
      );
      await ordered.dispose();
      await ordered.dispose();
      expect(() => ordered.classify('Hello'), throwsStateError);
      await expectLater(
        TextClassifier.create(
          TextClassifierOptions(modelBytes: Uint8List.fromList([1, 2, 3])),
        ),
        throwsA(isA<TaskException>()),
      );

      final use = await loadAssetBytes(
        bundledModelFile('universal_sentence_encoder.tflite'),
      );
      final embedder = await TextEmbedder.create(
        TextEmbedderOptions(modelBytes: use),
      );
      try {
        final greeting = (await embedder.embed(
          'Hello, world!',
        )).embeddings.single;
        final related = (await embedder.embed(
          'Hello there!',
        )).embeddings.single;
        final different = (await embedder.embed(
          'The spacecraft landed on Mars.',
        )).embeddings.single;
        expect(greeting.length, 100);
        expect(greeting.headIndex, 1);
        expect(greeting.headName, 'response_encoding');
        const first = [
          1.7475107908248901,
          -0.12642768025398254,
          -0.21085068583488464,
          1.524668574333191,
        ];
        for (final (i, value) in first.indexed) {
          expect(greeting.floatEmbedding![i], closeTo(value, _scoreBound));
        }
        expect(
          TextEmbedder.cosineSimilarity(greeting, related),
          closeTo(0.9605238, _scoreBound),
        );
        expect(
          TextEmbedder.cosineSimilarity(greeting, different),
          closeTo(0.8081205, _scoreBound),
        );
      } finally {
        await embedder.dispose();
      }
      final quantizer = await TextEmbedder.create(
        TextEmbedderOptions(modelBytes: use, l2Normalize: true, quantize: true),
      );
      try {
        final a = (await quantizer.embed('Hello, world!')).embeddings.single;
        final b = (await quantizer.embed('Hello there!')).embeddings.single;
        expect(a.quantizedEmbedding != null, isTrue);
        expect(a.quantizedEmbedding, hasLength(100));
        expect(TextEmbedder.cosineSimilarity(a, b), closeTo(0.9590452, 1e-2));
      } finally {
        await quantizer.dispose();
      }

      final detector = await LanguageDetector.create(
        LanguageDetectorOptions(
          modelBytes: await loadAssetBytes(
            bundledModelFile('language_detector.tflite'),
          ),
          maxResults: 3,
        ),
      );
      try {
        for (final (text, expected) in [
          (
            'Hello, world!',
            [('en', 0.994802), ('de', 0.001138), ('hu', 0.000523)],
          ),
          (
            'Quiero agua, por favor.',
            [('es', 0.998336), ('gl', 0.001423), ('pt', 0.000164)],
          ),
          (
            'こんにちは、元気ですか？',
            [('ja', 0.99923), ('ms', 0.000075), ('id', 0.000041)],
          ),
        ]) {
          final predictions = (await detector.detect(
            text,
          )).predictions.toList();
          expect(predictions.first.languageCode, expected.first.$1);
          for (final (i, (_, probability)) in expected.indexed) {
            expect(
              predictions[i].probability,
              closeTo(probability, _scoreBound),
            );
          }
        }
      } finally {
        await detector.dispose();
      }
      _report('text', {'checks': 'classifier, embedder, language detector'});
    });
  }, skip: !(Platform.isAndroid || Platform.isIOS));

  testWidgets('official SDK Audio Classifier matches Google\'s reference', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(
        audioTaskBackendFactory,
        isNull,
        reason:
            "Android and iOS run Google's C library through FFI, not a plugin backend",
      );
      final task = await AudioClassifier.create(
        AudioClassifierOptions(
          modelBytes: await loadAssetBytes(bundledModelFile('yamnet.tflite')),
          maxResults: 3,
        ),
      );
      try {
        final chunks = await task.classify(
          decodeWav(
            await loadAssetBytes('assets/samples/speech_16000_hz_mono.wav'),
          ),
        );
        const expected = [
          (0, 'Speech', 0.917969),
          (975, 'Speech', 0.992188),
          (1950, 'Speech', 0.984375),
          (2925, 'Speech', 0.996094),
          (3900, 'Tick', 0.261719),
        ];
        expect(chunks, hasLength(expected.length));
        var worst = 0.0;
        for (final (i, (timestamp, name, score)) in expected.indexed) {
          expect(chunks[i].timestampMilliseconds, timestamp);
          expect(
            chunks[i].classifications.first.categories.first.categoryName,
            name,
          );
          expect(
            chunks[i].classifications.first.categories.first.score,
            closeTo(score, _audioBound),
          );
          worst = math.max(
            worst,
            (chunks[i].classifications.first.categories.first.score - score)
                .abs(),
          );
        }
        // The 48 kHz recording of the same speech is resampled by Google's
        // task; it must still hear speech first.
        final resampled = await task.classify(
          decodeWav(
            await loadAssetBytes('assets/samples/speech_48000_hz_mono.wav'),
          ),
        );
        expect(
          resampled.first.classifications.first.categories.first.categoryName,
          'Speech',
        );
        _report('audio', {'max_top_score_delta': worst});
      } finally {
        await task.dispose();
      }
      expect(
        () => task.classify(
          AudioData(samples: Float32List(16000), sampleRate: 16000),
        ),
        throwsStateError,
      );
      // The default options: every category, as the native API returns.
      final every = await AudioClassifier.create(
        AudioClassifierOptions(
          modelBytes: await loadAssetBytes(bundledModelFile('yamnet.tflite')),
        ),
      );
      try {
        final chunks = await every.classify(
          decodeWav(
            await loadAssetBytes('assets/samples/speech_16000_hz_mono.wav'),
          ),
        );
        expect(
          chunks.first.classifications.first.categories.first.categoryName,
          'Speech',
        );
        expect(
          chunks.first.classifications.first.categories,
          hasLength(greaterThan(3)),
        );
      } finally {
        await every.dispose();
      }
      await expectLater(
        AudioClassifier.create(
          AudioClassifierOptions(modelBytes: Uint8List.fromList([1, 2, 3])),
        ),
        throwsA(isA<MediaPipeException>()),
      );
    });
  }, skip: !(Platform.isAndroid || Platform.isIOS));

  testWidgets(
    'official SDK Audio Classifier streams as Google\'s stream does',
    (tester) async {
      await tester.runAsync(() async {
        final model = await loadAssetBytes(bundledModelFile('yamnet.tflite'));
        final speech = decodeWav(
          await loadAssetBytes('assets/samples/speech_16000_hz_mono.wav'),
        );
        final resampled = decodeWav(
          await loadAssetBytes('assets/samples/speech_48000_hz_mono.wav'),
        );
        final google = <int>[];
        debugGoogleStreamTimestamp = google.add;
        try {
          // The same device's clips results, every category.
          final clips = await AudioClassifier.create(
            AudioClassifierOptions(modelBytes: model),
          );
          final List<AudioClassifierResult> clipChunks;
          try {
            clipChunks = await clips.classify(speech);
          } finally {
            await clips.dispose();
          }

          // 16 kHz in 100 ms blocks, a refused 48 kHz block in the middle.
          final mono = await _stream(model, speech, 1600, refuseRateAt: 5);
          expect(mono.results.map((r) => r.timestampMilliseconds), [
            0,
            975,
            1950,
            2925,
            3900,
          ]);
          // Google's own stamps: its stream flushed the tail at the close,
          // stamped with its sentinel, which no code of ours produces.
          expect(google, [0, 975, 1950, 2925, 9223372036854775]);
          expect(mono.beforeDispose, 4);
          // At the model's rate the stream feeds Google's model the same
          // floats as clips mode: equal to the last bit.
          final largest = _largestDifference(mono.results, clipChunks);
          expect(largest, 0.0);
          const reference = [
            ('Speech', 0.917969),
            ('Speech', 0.992188),
            ('Speech', 0.984375),
            ('Speech', 0.996094),
            ('Tick', 0.261719),
          ];
          for (final (i, (name, score)) in reference.indexed) {
            final top = mono.results[i].classifications.first.categories.first;
            expect(top.categoryName, name);
            expect(top.score, closeTo(score, _audioBound));
          }

          // 48 kHz in blocks of 4801, through Google's streaming resampler,
          // against its stream reference (speech-48k).
          google.clear();
          final fast = await _stream(model, resampled, 4801);
          const resampledReference = [
            (0, 'Speech', 0.941406),
            (975, 'Speech', 0.992188),
            (1950, 'Speech', 0.988281),
            (2925, 'Speech', 0.996094),
            (3900, 'Bouncing', 0.332031),
          ];
          expect(fast.results, hasLength(resampledReference.length));
          for (final (i, (timestamp, name, score))
              in resampledReference.indexed) {
            expect(fast.results[i].timestampMilliseconds, timestamp);
            final scores = {
              for (final c in fast.results[i].classifications.first.categories)
                c.categoryName: c.score,
            };
            expect(scores[name], closeTo(score, _audioBound), reason: '$i');
          }

          // Stereo with both channels equal mixes down to the mono stream.
          final stereo = Float32List(speech.samples.length * 2);
          for (var i = 0; i < speech.samples.length; i++) {
            stereo[2 * i] = stereo[2 * i + 1] = speech.samples[i];
          }
          final both = await _stream(
            model,
            AudioData(samples: stereo, sampleRate: 16000, channels: 2),
            1600,
          );
          expect(_largestDifference(both.results, mono.results), 0.0);

          // The lone half second: nothing until the close flushes it.
          google.clear();
          final lone = await _stream(
            model,
            AudioData(
              samples: Float32List.sublistView(speech.samples, 0, 8000),
              sampleRate: 16000,
            ),
            8000,
          );
          expect(lone.beforeDispose, 0);
          expect(lone.results.single.timestampMilliseconds, 0);
          expect(google, [9223372036854775]);

          _report('audio_stream', {
            'max_score_delta_vs_clips': largest,
            'results': mono.results.length,
            'dispose_ms': mono.disposeMilliseconds,
            'lone_dispose_ms': lone.disposeMilliseconds,
          });
        } finally {
          debugGoogleStreamTimestamp = null;
        }
      });
    },
    skip: !(Platform.isAndroid || Platform.isIOS),
  );
}

/// Streams [audio] in blocks of [blockFrames] frames, each stamped with its
/// first frame's time, waits for the full windows, then disposes, which
/// flushes the tail. With [refuseRateAt], that block is first offered at
/// 48 kHz, which Dart refuses before the stream goes on.
Future<
  ({
    List<AudioClassifierResult> results,
    int beforeDispose,
    int disposeMilliseconds,
  })
>
_stream(
  Uint8List model,
  AudioData audio,
  int blockFrames, {
  int? refuseRateAt,
}) async {
  final task = await AudioClassifier.create(
    AudioClassifierOptions(
      modelBytes: model,
      runningMode: AudioRunningMode.audioStream,
    ),
  );
  final results = <AudioClassifierResult>[];
  final done = Completer<void>();
  task.results.listen(
    results.add,
    onError: (Object error) => done.completeError(error),
    onDone: done.complete,
  );
  final rate = audio.sampleRate.toInt();
  final frames = audio.samples.length ~/ audio.channels;
  for (
    var start = 0, block = 0;
    start < frames;
    start += blockFrames, block++
  ) {
    final end = math.min(start + blockFrames, frames);
    final timestamp = start * 1000 ~/ rate;
    if (block == refuseRateAt) {
      expect(
        () => task.classifyAsync(
          AudioData(samples: Float32List(4800), sampleRate: 48000),
          timestampMilliseconds: timestamp,
        ),
        throwsArgumentError,
      );
    }
    task.classifyAsync(
      AudioData(
        samples: Float32List.sublistView(
          audio.samples,
          start * audio.channels,
          end * audio.channels,
        ),
        sampleRate: audio.sampleRate,
        channels: audio.channels,
      ),
      timestampMilliseconds: timestamp,
    );
  }
  final full = frames * 16000 ~/ rate ~/ 15600;
  for (var i = 0; i < 6000 && results.length < full; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final before = results.length;
  final clock = Stopwatch()..start();
  await task.dispose();
  await done.future;
  return (
    results: results,
    beforeDispose: before,
    disposeMilliseconds: clock.elapsedMilliseconds,
  );
}

/// The largest score difference between two lists of window results, over
/// every category; the categories and timestamps must match.
double _largestDifference(
  List<AudioClassifierResult> a,
  List<AudioClassifierResult> b,
) {
  expect(a, hasLength(b.length));
  var largest = 0.0;
  for (var i = 0; i < a.length; i++) {
    expect(a[i].timestampMilliseconds, b[i].timestampMilliseconds);
    final scores = {
      for (final c in b[i].classifications.first.categories) c.index: c.score,
    };
    final categories = a[i].classifications.first.categories;
    expect(categories.map((c) => c.index).toSet(), scores.keys.toSet());
    for (final c in categories) {
      largest = math.max(largest, (c.score - scores[c.index]!).abs());
    }
  }
  return largest;
}

// Kept in the device log (logcat, the simulator console) for the record.
void _report(String event, Map<String, Object?> data) =>
    logRecord('SDK_TEXT_AUDIO', {'event': event, ...data});

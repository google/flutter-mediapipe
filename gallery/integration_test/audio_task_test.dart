import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';

// The Audio Classifier demo's task, from the gallery's bundled YAMNet and
// sample clip, in the same app as the vision and text runtimes: core's shared
// runtime on macOS arm64, Linux x64 and Windows x64, where the gallery bundles
// it. The mobile and browser plugins have sdk_text_audio_test.dart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('audio classifier hears speech in the bundled clip', (
    tester,
  ) async {
    await tester.runAsync(() async {
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
        expect(chunks, hasLength(5));
        expect(
          chunks.first.classifications.first.categories.first.categoryName,
          'Speech',
        );
        // Google's Python output for this chunk on macOS. YAMNet's scores move
        // in 1/256 steps; the package suite compares each desktop host with
        // Google's library on that host.
        expect(
          chunks.first.classifications.first.categories.first.score,
          closeTo(0.917969, Platform.isMacOS ? 1e-5 : 2 / 256),
        );
      } finally {
        await task.dispose();
      }
    });
  }, skip: !(Platform.isMacOS || Platform.isLinux || Platform.isWindows));

  testWidgets('the clip as an audio stream gives the clip\'s five results', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final model = await loadAssetBytes(bundledModelFile('yamnet.tflite'));
      final speech = decodeWav(
        await loadAssetBytes('assets/samples/speech_16000_hz_mono.wav'),
      );
      final clips = await AudioClassifier.create(
        AudioClassifierOptions(modelBytes: model, maxResults: 3),
      );
      final List<AudioClassifierResult> clip;
      try {
        clip = await clips.classify(speech);
      } finally {
        await clips.dispose();
      }
      final stream = await AudioClassifier.create(
        AudioClassifierOptions(
          modelBytes: model,
          maxResults: 3,
          runningMode: AudioRunningMode.audioStream,
        ),
      );
      final heard = <AudioClassifierResult>[];
      final done = Completer<void>();
      stream.results.listen(heard.add, onDone: done.complete);
      // 100 ms blocks, each stamped with its first sample's time.
      for (var start = 0; start < speech.samples.length; start += 1600) {
        stream.classifyAsync(
          AudioData(
            samples: Float32List.sublistView(
              speech.samples,
              start,
              math.min(start + 1600, speech.samples.length),
            ),
            sampleRate: 16000,
          ),
          timestampMilliseconds: start * 1000 ~/ 16000,
        );
      }
      await stream.dispose();
      await done.future;
      // At the model's rate Google's stream feeds its model the same floats
      // as clips mode, the tail's zero padding included: the same results.
      expect(heard.map((r) => r.timestampMilliseconds), [
        0,
        975,
        1950,
        2925,
        3900,
      ]);
      for (final (i, result) in heard.indexed) {
        expect(
          [
            for (final c in result.classifications.single.categories)
              (c.categoryName, c.score),
          ],
          [
            for (final c in clip[i].classifications.single.categories)
              (c.categoryName, c.score),
          ],
        );
      }
    });
  }, skip: !(Platform.isMacOS || Platform.isLinux || Platform.isWindows));
}

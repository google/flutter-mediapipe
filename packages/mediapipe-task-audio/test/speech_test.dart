import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_audio/src/audio_task_backend.dart'
    show audioTranscriberOpener, browserOnMac;
import 'package:mediapipe_audio/src/litertlm_header.dart';
import 'package:mediapipe_audio/src/utf16_indices.dart';
import 'package:mediapipe_audio/src/third_party/mediapipe/audio_transcriber_bindings.dart'
    as asr;
import 'package:mediapipe_audio/src/third_party/mediapipe/text_to_speech_bindings.dart'
    as tts;
import 'package:mediapipe_core/src/native_assets/reference_wheels.dart'
    show releaseReferenceWheel;
import 'package:test/test.dart';

import 'support/metal_memory.dart';
import 'support/same_host_reference.dart';

const _fixtures = 'test/fixtures';
final _transcriberModel =
    'models/${Uri.parse(AudioModels.parakeetTdtV3.url).pathSegments.last}';
final _ttsModel =
    'models/${Uri.parse(AudioModels.phonon.url).pathSegments.last}';

final _kokoroModel =
    'models/${Uri.parse(AudioModels.kokoro.url).pathSegments.last}';

final _pocketTtsModel =
    'models/${Uri.parse(AudioModels.pocketTtsEn.url).pathSegments.last}';

/// The models CI downloads for this runner, which their tests must not skip
/// without: family.yaml names them.
final _requiredModels =
    (Platform.environment['MEDIAPIPE_REQUIRED_MODELS'] ?? '').split(' ');

/// Many sentences, so many chunks: the web probe's cancelled text.
const _cancelledText =
    'This stream stops at its first chunk. The second sentence never comes. '
    'Neither does the third. The fourth stays silent too. So does the fifth. '
    'The sixth has nothing to say. The seventh is the same. The eighth as well.';

/// Seconds of speech, which Phonon takes seconds to synthesize.
final _longText =
    'Cancelling this long text should stop it well before its end. ' * 40;

/// One clause of hundreds of words: Google analyses a clause's text before
/// its first chunk, which for this one takes a fraction of a second.
final _longClause =
    '${'the quick brown fox jumps over the lazy dog and ' * 100}it ends.';

/// Google's word times, rounded to four places in the reference.
const _secondsDelta = 1e-3;

/// More than Metal's own bookkeeping: the transcriber on the GPU holds hundreds
/// of megabytes there.
const _metalProof = 32 * 1024 * 1024;

/// The family library and the reference wheel's single library are separate
/// builds of Google's 1.2.3 release, so the audio gets a small bound: each
/// 100 ms window's RMS and the peak may move by this much.
const _levelDelta = 2e-3;

/// Google's 1.2.2 PocketTTS does not repeat itself on Linux x86-64: each new
/// task gives one of a few close answers, and which ones depends on the
/// process as well as the host, in Google's Python as in the package. Over
/// 600 of Google's own tasks on ten GitHub runners, every answer kept its
/// length and words, while a word's times moved by up to 60 ms and a window's
/// level by up to 0.009. So on Linux the PocketTTS comparisons allow 100 ms
/// and 0.02. Elsewhere Google's tasks agree, and the bounds above hold.
final _pocketTtsSecondsDelta = Platform.isLinux ? 0.1 : _secondsDelta;
final _pocketTtsLevelDelta = Platform.isLinux ? 2e-2 : _levelDelta;

/// Google's kMpCancelled, with its message.
Matcher _cancelledSynthesis() => isA<TaskException>()
    .having((error) => error.statusCode, 'statusCode', tts.mpCancelled)
    .having((error) => error.message, 'message', 'Synthesis cancelled.');

void main() {
  final reference = loadSameHostReference(
    'official_speech_reference.json',
    prefix: '',
    cases: 'cases',
    environment: 'MEDIAPIPE_SPEECH_REFERENCE_DIR',
    wheel: releaseReferenceWheel,
  );
  final cases = reference['cases'] as Map<String, dynamic>;
  final transcriberCases = cases['transcriber'] as Map<String, dynamic>;
  final speech = cases['text_to_speech'] as Map<String, dynamic>;
  final missingTranscriber = _missing(
    'Parakeet',
    _transcriberModel,
    'parakeet_tdt_v3',
  );
  final missingKokoro = _missing('Kokoro', _kokoroModel, 'kokoro');
  final missingTts = _missing('Phonon', _ttsModel, 'phonon');
  // Kokoro's own reference, from the same wheel, where its model is: the Mac.
  final kokoroSpeech = missingKokoro != null
      ? null
      : (loadSameHostReference(
                  'official_kokoro_reference.json',
                  prefix: 'kokoro_',
                  cases: 'cases',
                  environment: 'MEDIAPIPE_SPEECH_REFERENCE_DIR',
                  wheel: releaseReferenceWheel,
                )['cases']
                as Map<String, dynamic>)['text_to_speech']
            as Map<String, dynamic>;
  final missingPocketTts = _missing(
    'PocketTTS',
    _pocketTtsModel,
    'pocket_tts_en',
  );
  final pocketTtsReference = loadSameHostReference(
    'official_pocket_tts_reference.json',
    prefix: 'pocket_tts_',
    cases: 'cases',
    environment: 'MEDIAPIPE_SPEECH_REFERENCE_DIR',
    wheel: releaseReferenceWheel,
  );
  final pocketTts =
      (pocketTtsReference['cases'] as Map<String, dynamic>)['text_to_speech']
          as Map<String, dynamic>;

  test('the reference names the pinned models', () {
    expect(reference['models'], {
      'parakeet_tdt_0.6b_v3_5s_i8_stateful.litertlm':
          AudioModels.parakeetTdtV3.sha256,
      'phonon_int8.litertlm': AudioModels.phonon.sha256,
    });
    expect(pocketTtsReference['models'], {
      'pocket_tts_en_int8.litertlm': AudioModels.pocketTtsEn.sha256,
    });
  });

  group('AudioTranscriber', () {
    setUpAll(() {
      if (missingTranscriber != null) return;
      expect(
        sha256.convert(File(_transcriberModel).readAsBytesSync()).toString(),
        AudioModels.parakeetTdtV3.sha256,
      );
    });

    for (final MapEntry(key: name, value: expected as Map<String, dynamic>)
        in transcriberCases.entries) {
      test(
        '$name matches Google\'s Python API',
        skip: missingTranscriber,
        () async {
          final task = await AudioTranscriber.create(
            AudioTranscriberOptions(
              modelPath: _transcriberModel,
              sampleRateHz: expected['rate'] as int,
              enableInterimResults: expected['interim_results'] as bool,
            ),
          );
          addTearDown(task.dispose);
          final audio = _joined(
            decodeWav(File('$_fixtures/${expected['clip']}').readAsBytesSync()),
            copies: expected['copies'] as int,
            gapFrames: expected['gap_frames'] as int,
          );
          expect(audio.samples, hasLength(expected['frames']));
          final block = expected['block_frames'] as int?;
          // Each stream on the one task answers as Google's first did.
          for (
            var stream = 0;
            stream < (expected['streams'] as int);
            stream++
          ) {
            final calls = <List<Map<String, Object>>>[];
            if (block == null) {
              calls.add(_segments(await task.transcribe(audio)));
            } else {
              for (
                var start = 0;
                start < audio.samples.length;
                start += block
              ) {
                final part = AudioData(
                  samples: Float32List.sublistView(
                    audio.samples,
                    start,
                    math.min(start + block, audio.samples.length),
                  ),
                  sampleRate: audio.sampleRate,
                );
                calls.add(
                  _segments(await task.transcribe(part, endOfStream: false)),
                );
              }
            }
            expect(calls, expected['calls'], reason: 'stream $stream');
            final finish = _segments(await task.finishStream());
            expect(finish, expected['finish'], reason: 'stream $stream');
            if ((expected['copies'] as int) > 1) {
              _expectWindowed(
                calls,
                finish,
                // The same input in one call.
                whole:
                    (transcriberCases.values.firstWhere(
                                  (other) =>
                                      other['clip'] == expected['clip'] &&
                                      other['copies'] == expected['copies'] &&
                                      other['block_frames'] == null,
                                )['calls']
                                as List)
                            .single
                        as List,
                streamed: block != null,
                durationMs: audio.samples.length * 1000 / audio.sampleRate,
              );
            }
          }
        },
      );
    }

    test(
      'averages channels and joins segments as Google\'s text does',
      skip: missingTranscriber,
      () async {
        final task = await AudioTranscriber.create(
          AudioTranscriberOptions(modelPath: _transcriberModel),
        );
        addTearDown(task.dispose);
        final mono = decodeWav(
          File('$_fixtures/speech_16000_hz_mono.wav').readAsBytesSync(),
        );
        final stereo = Float32List(mono.samples.length * 2);
        for (var i = 0; i < mono.samples.length; i++) {
          stereo[2 * i] = stereo[2 * i + 1] = mono.samples[i];
        }
        final result = await task.transcribe(
          AudioData(samples: stereo, sampleRate: 16000, channels: 2),
        );
        final expected =
            (transcriberCases['speech-16k']['calls'] as List).single as List;
        expect(_segments(result), expected);
        expect(result.text, (expected.single as Map)['transcript']);
        await expectLater(
          task.transcribe(AudioData(samples: mono.samples, sampleRate: 48000)),
          throwsArgumentError,
        );
        await task.prewarm();
        await task.dispose();
        await task.dispose();
        expect(() => task.transcribe(mono), throwsStateError);
      },
    );

    // Google's library accepts the GPU delegate and can stay on the CPU, as
    // its Text to Speech does with Phonon, and the answer reads the same: so
    // the proof is the memory the task holds on Metal. The package job runs it
    // on each macOS version the capabilities claim.
    test(
      'runs on the GPU on this Mac',
      skip: Abi.current() != Abi.macosArm64
          ? 'Only on a Mac.'
          : missingTranscriber,
      timeout: const Timeout(Duration(minutes: 10)),
      () async {
        expect(
          (await queryAudioTranscriberCapabilities()).supportedDelegates,
          contains(Delegate.gpu),
        );
        final audio = decodeWav(
          File('$_fixtures/speech_16000_hz_mono.wav').readAsBytesSync(),
        );
        final expected =
            (transcriberCases['speech-16k']['calls'] as List).single as List;
        Future<int> grown(Delegate delegate) async {
          final before = metalAllocatedBytes();
          final task = await AudioTranscriber.create(
            AudioTranscriberOptions(
              modelPath: _transcriberModel,
              delegate: delegate,
            ),
          );
          try {
            final result = await task.transcribe(audio);
            expect(result.text, (expected.single as Map)['transcript']);
            return metalAllocatedBytes() - before;
          } finally {
            await task.dispose();
          }
        }

        final onCpu = await grown(Delegate.cpu);
        final onGpu = await grown(Delegate.gpu);
        // ignore: avoid_print
        print('Metal bytes the transcriber added: CPU $onCpu, GPU $onGpu');
        expect(onGpu, greaterThan(onCpu + _metalProof));
      },
    );

    // Google's answer to no audio is no segments, in a whole clip and in a
    // stream's block alike.
    test('empty audio gives no segments', skip: missingTranscriber, () async {
      final task = await AudioTranscriber.create(
        AudioTranscriberOptions(modelPath: _transcriberModel),
      );
      addTearDown(task.dispose);
      final empty = AudioData(samples: Float32List(0), sampleRate: 16000);
      expect((await task.transcribe(empty)).segments, isEmpty);
      expect(
        (await task.transcribe(empty, endOfStream: false)).segments,
        isEmpty,
      );
      expect((await task.finishStream()).segments, isEmpty);
      final audio = decodeWav(
        File('$_fixtures/speech_16000_hz_mono.wav').readAsBytesSync(),
      );
      final expected =
          (transcriberCases['speech-16k']['calls'] as List).single as List;
      expect(_segments(await task.transcribe(audio)), expected);
    });

    test(
      'dispose waits for a call in flight, then refuses calls',
      skip: missingTranscriber,
      () async {
        final task = await AudioTranscriber.create(
          AudioTranscriberOptions(modelPath: _transcriberModel),
        );
        final audio = decodeWav(
          File('$_fixtures/speech_16000_hz_mono.wav').readAsBytesSync(),
        );
        final pending = task.transcribe(audio);
        final disposed = task.dispose();
        final expected =
            (transcriberCases['speech-16k']['calls'] as List).single as List;
        expect(_segments(await pending), expected);
        await disposed;
        expect(() => task.transcribe(audio), throwsStateError);
        expect(task.finishStream, throwsStateError);
      },
    );
  });

  group('TextToSpeech', () {
    late TextToSpeech task;
    setUpAll(() async {
      if (missingTts != null) return;
      expect(
        sha256.convert(File(_ttsModel).readAsBytesSync()).toString(),
        AudioModels.phonon.sha256,
      );
      task = await TextToSpeech.create(
        TextToSpeechOptions(modelPath: _ttsModel),
      );
    });
    tearDownAll(() async {
      if (missingTts == null) await task.dispose();
    });

    test('lists Google\'s voices', skip: missingTts, () async {
      expect([
        for (final voice in await task.listVoices())
          {
            'voice_id': voice.voiceId,
            'display_name': voice.displayName,
            'locale': voice.locale,
            'sample_rate_hz': voice.sampleRateHz,
            'is_downloaded': voice.isDownloaded,
          },
      ], speech['voices']);
    });

    final utterances = speech['utterances'] as Map<String, dynamic>;
    for (final MapEntry(key: name, value: expected as Map<String, dynamic>)
        in utterances.entries) {
      test('$name matches Google\'s Python API', skip: missingTts, () async {
        final text = expected['text'] as String;
        _expectAudio(
          await task.synthesize(
            text,
            voiceId: expected['voice_id'] as String?,
            locale: expected['locale'] as String?,
          ),
          text,
          expected,
        );
      });
    }

    test(
      'a stream\'s chunks match Google\'s Python API',
      skip: missingTts,
      () async {
        final stream = speech['stream'] as Map<String, dynamic>;
        final text = stream['text'] as String;
        final chunks = await task.synthesizeStream(text).toList();
        final expected = (stream['chunks'] as List)
            .cast<Map<String, dynamic>>();
        expect(chunks, hasLength(expected.length));
        for (final (i, chunk) in chunks.indexed) {
          expect(chunk.chunkIndex, expected[i]['chunk_index']);
          expect(chunk.isFinal, expected[i]['is_final']);
          _expectAudio(chunk, text, expected[i]);
        }
      },
    );

    // One chunk reaches the listener whether or not the cancel reaches
    // Google: so the proof is time. Leaving the loop waits for the worker to
    // end the request, which on a text of many chunks comes long before the
    // whole stream would.
    test(
      'cancelling a stream stops Google\'s, and the task still answers',
      skip: missingTts,
      () async {
        final whole = Stopwatch()..start();
        final chunks = await task.synthesizeStream(_cancelledText).length;
        whole.stop();
        expect(chunks, greaterThan(8));
        final cancelled = Stopwatch()..start();
        var received = 0;
        await for (final chunk in task.synthesizeStream(_cancelledText)) {
          expect(chunk.chunkIndex, 0);
          received++;
          break;
        }
        cancelled.stop();
        expect(received, 1);
        // ignore: avoid_print
        print(
          'The whole stream: $chunks chunks in ${whole.elapsedMilliseconds} '
          'ms; cancelled at its first: ${cancelled.elapsedMilliseconds} ms',
        );
        // A quarter leaves room for a busy machine: on a developer's Mac the
        // cancelled stream ends in about a hundredth of the whole one's time.
        expect(cancelled.elapsed, lessThan(whole.elapsed ~/ 4));
        final fox = utterances['fox'] as Map<String, dynamic>;
        _expectAudio(
          await task.synthesize(fox['text'] as String),
          fox['text'] as String,
          fox,
        );
      },
    );

    // Google cancels a synthesis it runs; a call still queued behind it, or
    // one the worker has not started, fails before it starts.
    test(
      'cancel fails calls not yet started, and a stream before its first '
      'chunk',
      skip: missingTts,
      () async {
        final running = expectLater(
          task.synthesize(_longText),
          throwsA(_cancelledSynthesis()),
        );
        final queued = expectLater(
          task.synthesize(_cancelledText),
          throwsA(_cancelledSynthesis()),
        );
        final chunks = task.synthesizeStream(_cancelledText).toList();
        final watch = Stopwatch()..start();
        task.cancel();
        await running;
        await queued;
        expect(await chunks, isEmpty);
        // ignore: avoid_print
        print('Three calls cancelled in ${watch.elapsedMilliseconds} ms');
      },
    );

    // The cancel comes a tenth of the way in, so it finds Google
    // synthesizing whatever the machine's speed: only its latency is timed.
    test(
      'cancel stops a long synthesis well before it would finish',
      skip: missingTts,
      () async {
        final whole = Stopwatch()..start();
        final audio = await task.synthesize(_longText);
        whole.stop();
        expect(audio.samples.length, greaterThan(audio.sampleRateHz * 60));
        final pending = expectLater(
          task.synthesize(_longText),
          throwsA(_cancelledSynthesis()),
        );
        await Future<void>.delayed(whole.elapsed ~/ 10);
        final cancelled = Stopwatch()..start();
        task.cancel();
        await pending;
        cancelled.stop();
        // ignore: avoid_print
        print(
          'The whole synthesis: ${whole.elapsedMilliseconds} ms; failed '
          '${cancelled.elapsedMilliseconds} ms after its cancel',
        );
        // On a developer's Mac a cancel lands within a few milliseconds of
        // a synthesis of seconds.
        expect(cancelled.elapsed, lessThan(whole.elapsed ~/ 4));
      },
    );

    // Google checks for a cancel only between the audio's frames, not while
    // it analyses a clause's text: so a stream cancelled during the longest
    // read Phonon has, its first, ends once that analysis does, with no
    // chunk. The cancel comes a tenth of the way into the read.
    test(
      'cancelling a stream during its longest read ends it with no chunk',
      skip: missingTts,
      () async {
        final first = Stopwatch()..start();
        await task.synthesizeStream(_longClause).first;
        first.stop();
        var received = 0;
        final ended = Completer<void>();
        final subscription = task
            .synthesizeStream(_longClause)
            .listen(
              (_) => received++,
              onError: ended.completeError,
              onDone: ended.complete,
            );
        await Future<void>.delayed(first.elapsed ~/ 10);
        final cancelled = Stopwatch()..start();
        await subscription.cancel();
        cancelled.stop();
        expect(received, 0);
        expect(ended.isCompleted, isFalse);
        // ignore: avoid_print
        print(
          'The first chunk: ${first.elapsedMilliseconds} ms; the cancel '
          'returned in ${cancelled.elapsedMilliseconds} ms',
        );
        // The analysis in progress, with room for a busy machine.
        expect(
          cancelled.elapsed,
          lessThan(first.elapsed * 2 + const Duration(seconds: 2)),
        );
      },
    );

    test(
      'cancel ends a stream in progress without an error',
      skip: missingTts,
      () async {
        final whole = Stopwatch()..start();
        final all = await task.synthesizeStream(_longText).length;
        whole.stop();
        final cancelled = Stopwatch();
        final chunks = await task.synthesizeStream(_longText).map((chunk) {
          if (chunk.chunkIndex == 2) {
            cancelled.start();
            task.cancel();
          }
          return chunk;
        }).length;
        cancelled.stop();
        // ignore: avoid_print
        print(
          'The whole stream: $all chunks in ${whole.elapsedMilliseconds} ms; '
          'cancelled at its third: $chunks chunks, ended '
          '${cancelled.elapsedMilliseconds} ms after its cancel',
        );
        expect(chunks, inInclusiveRange(3, all ~/ 4));
        expect(cancelled.elapsed, lessThan(whole.elapsed ~/ 4));
      },
    );

    test(
      'after a cancel the task answers as before',
      skip: missingTts,
      () async {
        final fox = utterances['fox'] as Map<String, dynamic>;
        final text = fox['text'] as String;
        final pending = task.synthesize(_longText);
        task.cancel();
        await expectLater(pending, throwsA(_cancelledSynthesis()));
        _expectAudio(await task.synthesize(text), text, fox);
        final stream = speech['stream'] as Map<String, dynamic>;
        final chunks = await task
            .synthesizeStream(stream['text'] as String)
            .toList();
        expect(chunks, hasLength((stream['chunks'] as List).length));
        expect(
          await task.listVoices(),
          hasLength((speech['voices'] as List).length),
        );
      },
    );

    test(
      'cancel does nothing with nothing in flight, or after dispose',
      skip: missingTts,
      () async {
        final fox = utterances['fox'] as Map<String, dynamic>;
        final text = fox['text'] as String;
        task.cancel();
        task.cancel();
        _expectAudio(await task.synthesize(text), text, fox);
        final other = await TextToSpeech.create(
          TextToSpeechOptions(modelPath: _ttsModel),
        );
        await other.dispose();
        other.cancel();
        other.cancel();
        expect(() => other.synthesize(text), throwsStateError);
      },
    );

    // The cancels land before, during and after the worker closes Google's
    // task and the guard is freed, which a cancel must then leave alone.
    test(
      'cancel racing dispose fails the call in flight, and dispose completes',
      skip: missingTts,
      () async {
        final other = await TextToSpeech.create(
          TextToSpeechOptions(modelPath: _ttsModel),
        );
        final pending = expectLater(
          other.synthesize(_longText),
          throwsA(_cancelledSynthesis()),
        );
        final stream = other.synthesizeStream(_longText).length;
        final disposed = other.dispose();
        var cancels = 0;
        var done = false;
        unawaited(disposed.whenComplete(() => done = true));
        other.cancel();
        while (!done) {
          other.cancel();
          cancels++;
          await Future<void>.delayed(Duration.zero);
        }
        for (var i = 0; i < 100; i++) {
          other.cancel();
        }
        await pending;
        expect(await stream, 0);
        await disposed;
        // ignore: avoid_print
        print('$cancels cancels while dispose ran');
        expect(cancels, greaterThan(0));
      },
    );

    test('speaks at the options\' rate', skip: missingTts, () async {
      final fast = speech['fast'] as Map<String, dynamic>;
      final quick = await TextToSpeech.create(
        TextToSpeechOptions(
          modelPath: _ttsModel,
          speakingRate: (fast['speaking_rate'] as num).toDouble(),
        ),
      );
      addTearDown(quick.dispose);
      final text = fast['text'] as String;
      _expectAudio(await quick.synthesize(text), text, fast);
    });

    // Google's task accepts the GPU delegate for Phonon and runs it on the
    // CPU, holding nothing on Metal: its bundle marks no section for the GPU.
    test('refuses the GPU for Phonon', skip: missingTts, () async {
      await expectLater(
        TextToSpeech.create(
          TextToSpeechOptions(modelPath: _ttsModel, delegate: Delegate.gpu),
        ),
        throwsA(
          isA<RuntimeUnavailableException>().having(
            (error) => error.fix,
            'fix',
            Abi.current() == Abi.macosArm64
                ? contains('marks none')
                : contains('proved'),
          ),
        ),
      );
    });

    // Kokoro's vocoder runs on Metal, which the answer alone cannot show
    // (the GPU's audio differs from the CPU's in its phase, not its words):
    // so the proof is the memory the task holds there.
    test(
      'runs Kokoro on the GPU on this Mac',
      skip: Abi.current() != Abi.macosArm64 ? 'Only on a Mac.' : missingKokoro,
      timeout: const Timeout(Duration(minutes: 10)),
      () async {
        expect(
          sha256.convert(File(_kokoroModel).readAsBytesSync()).toString(),
          AudioModels.kokoro.sha256,
        );
        expect(
          (await queryTextToSpeechCapabilities()).supportedDelegates,
          contains(Delegate.gpu),
        );
        const text = 'The quick brown fox jumps over the lazy dog.';
        Future<(int, TextToSpeechResult)> run(Delegate delegate) async {
          final before = metalAllocatedBytes();
          final kokoro = await TextToSpeech.create(
            TextToSpeechOptions(modelPath: _kokoroModel, delegate: delegate),
          );
          try {
            final speech = await kokoro.synthesize(text);
            return (metalAllocatedBytes() - before, speech);
          } finally {
            await kokoro.dispose();
          }
        }

        final (onCpu, cpu) = await run(Delegate.cpu);
        final (onGpu, gpu) = await run(Delegate.gpu);
        // ignore: avoid_print
        print('Metal bytes Kokoro added: CPU $onCpu, GPU $onGpu');
        expect(onCpu, lessThan(_metalProof));
        expect(onGpu, greaterThan(onCpu + _metalProof));
        // The acoustic model runs on the CPU either way, so the words take
        // the same time; the GPU's FP16 vocoder gives each 100 ms window
        // nearly the same level.
        expect(gpu.sampleRateHz, cpu.sampleRateHz);
        expect(gpu.samples.length, cpu.samples.length);
        expect(cpu.samples.length, greaterThan(cpu.sampleRateHz));
        final window = cpu.sampleRateHz ~/ 10;
        for (
          var start = 0;
          start + window <= cpu.samples.length;
          start += window
        ) {
          expect(
            _windowRms(gpu.samples, start, window),
            closeTo(_windowRms(cpu.samples, start, window), 0.02),
            reason: 'window at $start',
          );
        }
        expect(
          _windowRms(gpu.samples, 0, gpu.samples.length),
          greaterThan(0.01),
        );
      },
    );

    test('a disposed task refuses calls', skip: missingTts, () async {
      final other = await TextToSpeech.create(
        TextToSpeechOptions(modelPath: _ttsModel),
      );
      await other.dispose();
      await other.dispose();
      expect(() => other.synthesize('Hello.'), throwsStateError);
      expect(() => other.synthesizeStream('Hello.'), throwsStateError);
    });

    // Google speaks no text as no audio, as its Python does: no error.
    test('empty text gives no audio', skip: missingTts, () async {
      for (final text in ['', '   ']) {
        final result = await task.synthesize(text);
        expect(result.samples, isEmpty, reason: '"$text"');
        expect(result.sampleRateHz, 24000);
        expect(result.wordTimestamps, isEmpty);
      }
      expect(await task.synthesizeStream('').toList(), isEmpty);
    });

    test(
      'a long text completes, its length in step with the text',
      skip: missingTts,
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        const sentence = 'The quick brown fox jumps over the lazy dog. ';
        final one = await task.synthesize(sentence);
        final text = sentence * 70;
        expect(text.length, greaterThan(3000));
        final long = await task.synthesize(text);
        expect(long.wordTimestamps, hasLength(70 * one.wordTimestamps.length));
        expect(
          text.substring(
            long.wordTimestamps.last.start,
            long.wordTimestamps.last.end,
          ),
          'dog.',
        );
        expect(
          long.samples.length / one.samples.length,
          inInclusiveRange(63, 77),
        );
        expect(
          long.wordTimestamps.last.endSeconds,
          lessThanOrEqualTo(long.samples.length / long.sampleRateHz),
        );
      },
    );

    test(
      'dispose waits for a call in flight, then refuses calls',
      skip: missingTts,
      () async {
        final other = await TextToSpeech.create(
          TextToSpeechOptions(modelPath: _ttsModel),
        );
        final fox = utterances['fox'] as Map<String, dynamic>;
        final text = fox['text'] as String;
        final pending = other.synthesize(text);
        final voices = other.listVoices();
        final disposed = other.dispose();
        _expectAudio(await pending, text, fox);
        expect(await voices, hasLength((speech['voices'] as List).length));
        await disposed;
        expect(() => other.synthesize(text), throwsStateError);
        expect(other.listVoices, throwsStateError);
      },
    );
  });

  group('a model path that is no model', () {
    final errors = _errorReference();
    final outcomes = {
      for (final MapEntry(key: task, value: table)
          in (errors?['cases'] as Map<String, dynamic>? ?? {}).entries)
        for (final MapEntry(key: name, value: outcome)
            in (table as Map<String, dynamic>).entries)
          '$task $name': outcome as Map<String, dynamic>,
    };
    Directory? root;
    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('speech_errors');
    });
    tearDownAll(() async => root?.delete(recursive: true));

    for (final MapEntry(key: name, value: outcome) in outcomes.entries) {
      final task = name.split(' ').first;
      // Where the package checks the path before Google's library sees it.
      final checked =
          task == 'text_to_speech' &&
          Platform.isLinux &&
          outcome['kind'] != 'file';
      test(
        checked
            ? '$name fails with the package\'s NOT_FOUND, never an abort'
            : '$name fails with Google\'s status and message',
        () async {
          if (outcome['aborted'] == true && !checked) {
            fail('Google ends the process here: ${outcome['log']}');
          }
          final path = await _noModel(root!, outcome);
          await expectLater(
            task == 'transcriber'
                ? AudioTranscriber.create(
                    AudioTranscriberOptions(modelPath: path),
                  )
                : TextToSpeech.create(TextToSpeechOptions(modelPath: path)),
            throwsA(checked ? _noModelFile(path) : _googleError(outcome, path)),
          );
        },
      );
    }

    test(
      'Google ends the process only on Linux, for Text to Speech',
      () {
        final aborted = [
          for (final MapEntry(key: name, value: outcome) in outcomes.entries)
            if (outcome['aborted'] == true) name,
        ];
        // When Google's Linux library stops aborting, the package's own
        // check, _requireModelFile, can go.
        expect(aborted, Platform.isLinux ? isNotEmpty : isEmpty);
      },
      skip: errors == null
          ? 'No same-host speech error reference: run '
                'tool/prepare_speech_reference.py --errors-only.'
          : false,
    );
  });

  group('Kokoro on the CPU', () {
    late TextToSpeech kokoro;
    setUpAll(() async {
      if (missingKokoro != null) return;
      expect(
        sha256.convert(File(_kokoroModel).readAsBytesSync()).toString(),
        AudioModels.kokoro.sha256,
      );
      kokoro = await TextToSpeech.create(
        TextToSpeechOptions(modelPath: _kokoroModel),
      );
    });
    tearDownAll(() async {
      if (missingKokoro == null) await kokoro.dispose();
    });

    test('lists Google\'s voices', skip: missingKokoro, () async {
      expect([
        for (final voice in await kokoro.listVoices())
          {
            'voice_id': voice.voiceId,
            'display_name': voice.displayName,
            'locale': voice.locale,
            'sample_rate_hz': voice.sampleRateHz,
            'is_downloaded': voice.isDownloaded,
          },
      ], kokoroSpeech!['voices']);
    });

    for (final name in ['fox', 'siwis-fr']) {
      test('$name matches Google\'s Python API', skip: missingKokoro, () async {
        final expected =
            (kokoroSpeech!['utterances'] as Map<String, dynamic>)[name]
                as Map<String, dynamic>;
        final text = expected['text'] as String;
        _expectAudio(
          await kokoro.synthesize(
            text,
            voiceId: expected['voice_id'] as String?,
            locale: expected['locale'] as String?,
          ),
          text,
          expected,
        );
      });
    }

    // A Kokoro voice speaks only its own locale, so a default voice that is
    // not US English shows which locale the options' default gives. Google's
    // C API, Web, Android and iOS leave it unset, inferred from the voice;
    // its Python alone defaults to en-US, which refuses the voice.
    test(
      'a default voice speaks its own locale unless another is given',
      skip: missingKokoro,
      () async {
        final defaults = kokoroSpeech!['default_voice'] as Map<String, dynamic>;
        final text = defaults['text'] as String;
        final voiceId = defaults['voice_id'] as String;
        final locale = defaults['locale'] as String;
        expect(defaults['inferred'], defaults['voice_locale']);
        final task = await TextToSpeech.create(
          TextToSpeechOptions(modelPath: _kokoroModel, defaultVoiceId: voiceId),
        );
        addTearDown(task.dispose);
        _expectAudio(await task.synthesize(text), text, defaults['inferred']);
        _expectAudio(
          await task.synthesize(text, locale: locale),
          text,
          defaults['voice_locale'],
        );
        // Python's message is its C API's status and message.
        final [
          status,
          message,
        ] = RegExp(r'^TextToSpeech C API error \((\d+)\): (.*)$', dotAll: true)
            .firstMatch((defaults['en-US'] as Map)['error'] as String)!
            .groups([1, 2]);
        final english = await TextToSpeech.create(
          TextToSpeechOptions(
            modelPath: _kokoroModel,
            defaultVoiceId: voiceId,
            defaultLocale: 'en-US',
          ),
        );
        addTearDown(english.dispose);
        await expectLater(
          english.synthesize(text),
          throwsA(
            isA<TaskException>()
                .having((e) => e.statusCode, 'statusCode', int.parse(status!))
                .having((e) => e.message, 'message', contains(message!)),
          ),
        );
      },
    );
  });

  // Kyutai's PocketTTS English (AudioModels.pocketTtsEn), against Google's
  // Python on the same model, as Phonon is above.
  group('TextToSpeech with PocketTTS English', () {
    late TextToSpeech task;
    setUpAll(() async {
      if (missingPocketTts != null) return;
      expect(
        sha256.convert(File(_pocketTtsModel).readAsBytesSync()).toString(),
        AudioModels.pocketTtsEn.sha256,
      );
      task = await TextToSpeech.create(
        TextToSpeechOptions(modelPath: _pocketTtsModel),
      );
    });
    tearDownAll(() async {
      if (missingPocketTts == null) await task.dispose();
    });

    // Google's page says the English bundle "includes only English voices",
    // these eight with alba the default, but its 1.2.3 runtime, Python's too,
    // also lists the multilingual bundle's six others for it.
    test('lists Google\'s voices', skip: missingPocketTts, () async {
      final voices = await task.listVoices();
      expect([
        for (final voice in voices)
          {
            'voice_id': voice.voiceId,
            'display_name': voice.displayName,
            'locale': voice.locale,
            'sample_rate_hz': voice.sampleRateHz,
            'is_downloaded': voice.isDownloaded,
          },
      ], pocketTts['voices']);
      expect(voices.first.voiceId, 'alba');
      expect(
        voices
            .where((voice) => voice.locale == 'en-US')
            .map((voice) => voice.voiceId)
            .toSet(),
        {
          'alba',
          'azelma',
          'cosette',
          'eponine',
          'fantine',
          'javert',
          'jean',
          'marius',
        },
      );
    });

    final utterances = pocketTts['utterances'] as Map<String, dynamic>;
    for (final MapEntry(key: name, value: expected as Map<String, dynamic>)
        in utterances.entries) {
      test(
        '$name matches Google\'s Python API',
        skip: missingPocketTts,
        () async {
          final text = expected['text'] as String;
          final speech = await task.synthesize(
            text,
            voiceId: expected['voice_id'] as String?,
          );
          _expectOneOfGoogles<Map<String, dynamic>>(
            expected,
            expected['alternatives'] as List?,
            (answer) => _expectPocketTtsAudio(speech, text, answer),
          );
          // PocketTTS times every word, which _expectAudio compares.
          expect(speech.wordTimestamps, isNotEmpty);
        },
      );
    }

    test(
      'a stream\'s chunks match Google\'s Python API and the whole text',
      skip: missingPocketTts,
      () async {
        final stream = pocketTts['stream'] as Map<String, dynamic>;
        final text = stream['text'] as String;
        final chunks = await task.synthesizeStream(text).toList();
        _expectOneOfGoogles<List>(
          stream['chunks'] as List,
          stream['alternatives'] as List?,
          (answer) {
            final expected = answer.cast<Map<String, dynamic>>();
            expect(chunks, hasLength(expected.length));
            for (final (i, chunk) in chunks.indexed) {
              expect(chunk.chunkIndex, expected[i]['chunk_index']);
              expect(chunk.isFinal, expected[i]['is_final']);
              _expectPocketTtsAudio(chunk, text, expected[i]);
            }
          },
        );
        // One call returns the chunks joined.
        final whole = await task.synthesize(text);
        final joined = Float32List.fromList([
          for (final chunk in chunks) ...chunk.samples,
        ]);
        expect(whole.samples, hasLength(joined.length));
        final window = whole.sampleRateHz ~/ 10;
        for (var start = 0; start + window <= joined.length; start += window) {
          expect(
            _windowRms(whole.samples, start, window),
            closeTo(_windowRms(joined, start, window), _levelDelta),
            reason: 'window at $start',
          );
        }
      },
    );

    test('speaks at the options\' rate', skip: missingPocketTts, () async {
      final fast = pocketTts['fast'] as Map<String, dynamic>;
      final quick = await TextToSpeech.create(
        TextToSpeechOptions(
          modelPath: _pocketTtsModel,
          speakingRate: (fast['speaking_rate'] as num).toDouble(),
        ),
      );
      addTearDown(quick.dispose);
      final text = fast['text'] as String;
      final speech = await quick.synthesize(text);
      _expectOneOfGoogles<Map<String, dynamic>>(
        fast,
        fast['alternatives'] as List?,
        (answer) => _expectPocketTtsAudio(speech, text, answer),
      );
      final normal = utterances['fox'] as Map<String, dynamic>;
      expect(normal['text'], text);
      expect(speech.samples.length, lessThan(0.8 * (normal['samples'] as int)));
    });

    // Google's page runs PocketTTS on the CPU, and its bundle's header marks
    // no section for the GPU, so the package refuses the GPU delegate.
    test(
      'refuses the GPU, as its header marks none',
      skip: missingPocketTts,
      () async {
        final file = File(_pocketTtsModel).openSync();
        try {
          final end = litertlmHeaderEnd(file.readSync(litertlmPreambleBytes));
          expect(end, isNotNull);
          file.setPositionSync(0);
          expect(litertlmHasGpuSection(file.readSync(end!)), isFalse);
        } finally {
          file.closeSync();
        }
        await expectLater(
          TextToSpeech.create(
            TextToSpeechOptions(
              modelPath: _pocketTtsModel,
              delegate: Delegate.gpu,
            ),
          ),
          throwsA(
            isA<RuntimeUnavailableException>().having(
              (error) => error.fix,
              'fix',
              Abi.current() == Abi.macosArm64
                  ? contains('marks none')
                  : contains('proved'),
            ),
          ),
        );
      },
    );
  });

  test('options refuse the values Google rejects, and read 0 Hz as 16000', () {
    // A model source, so that only the value under test can be refused.
    Matcher refuses(String name) =>
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', name));
    AudioTranscriberOptions transcriber(int rate) => AudioTranscriberOptions(
      modelPath: 'parakeet.litertlm',
      sampleRateHz: rate,
    );
    // Google's C header: 0 means 16000 Hz, and negative rates are invalid.
    expect(transcriber(0).sampleRateHz, 16000);
    expect(transcriber(48000).sampleRateHz, 48000);
    expect(() => transcriber(-1), refuses('sampleRateHz'));
    TextToSpeechOptions speech(double rate) =>
        TextToSpeechOptions(modelPath: 'phonon.litertlm', speakingRate: rate);
    for (final rate in [0.0, -1.0, 4.5]) {
      expect(() => speech(rate), refuses('speakingRate'));
    }
    expect(speech(4).speakingRate, 4);
    // Google's guide lists Kokoro's buckets as 0, 64, 128 and 256.
    TextToSpeechOptions kokoro(int bucket) =>
        TextToSpeechOptions(modelPath: 'kokoro.litertlm', targetBucket: bucket);
    for (final bucket in [-1, 32, 512]) {
      expect(() => kokoro(bucket), refuses('targetBucket'));
    }
    for (final bucket in [0, 64, 128, 256]) {
      expect(kokoro(bucket).targetBucket, bucket);
    }
  });

  test('each speech task offers the GPU only where it is proved', () async {
    expect((await queryTextToSpeechCapabilities()).supportedDelegates, {
      Delegate.cpu,
      if (Abi.current() == Abi.macosArm64) Delegate.gpu,
    });
    const mac = TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '15.0',
    );
    expect(audioTranscriberCapabilitiesForPlatform(mac).supportedDelegates, {
      Delegate.cpu,
      Delegate.gpu,
    });
    expect(textToSpeechCapabilitiesForPlatform(mac).supportedDelegates, {
      Delegate.cpu,
      Delegate.gpu,
    });
    // Kokoro has never run on macOS 14, which CI no longer runs.
    const mac14 = TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '14.0',
    );
    expect(textToSpeechCapabilitiesForPlatform(mac14).supportedDelegates, {
      Delegate.cpu,
    });
    expect(audioTranscriberCapabilitiesForPlatform(mac14).supportedDelegates, {
      Delegate.cpu,
      Delegate.gpu,
    });
    // An iPhone or iPad is offered the transcriber's GPU, which did the work
    // on an iPhone 15 Pro; the iOS Simulator is not.
    const iphone = TaskPlatform(
      operatingSystem: 'ios',
      architecture: 'arm64',
      version: '17.0',
    );
    expect(audioTranscriberCapabilitiesForPlatform(iphone).supportedDelegates, {
      Delegate.cpu,
      Delegate.gpu,
    });
    const simulator = TaskPlatform(
      operatingSystem: 'ios',
      architecture: 'arm64',
      version: '17.0',
      simulator: true,
    );
    final onSimulator = audioTranscriberCapabilitiesForPlatform(simulator);
    expect(onSimulator.supportedDelegates, {Delegate.cpu});
    expect(onSimulator.unavailableReasons[Delegate.gpu], contains('proved'));
    for (final platform in const [
      TaskPlatform(operatingSystem: 'linux', architecture: 'x64'),
      TaskPlatform(operatingSystem: 'windows', architecture: 'x64'),
      TaskPlatform(operatingSystem: 'android', architecture: 'arm64'),
      iphone,
    ]) {
      final speech = textToSpeechCapabilitiesForPlatform(platform);
      expect(speech.supportedDelegates, {Delegate.cpu}, reason: '$platform');
      expect(
        speech.unavailableReasons[Delegate.gpu],
        allOf(contains('proved'), contains('Kokoro')),
        reason: '$platform',
      );
      if (platform == iphone) continue;
      final capabilities = audioTranscriberCapabilitiesForPlatform(platform);
      expect(capabilities.supportedDelegates, {
        Delegate.cpu,
      }, reason: '$platform');
      expect(
        capabilities.unavailableReasons[Delegate.gpu],
        contains('proved'),
        reason: '$platform',
      );
    }
    const browser = TaskPlatform(operatingSystem: 'web', architecture: 'wasm');
    expect(audioTranscriberCapabilitiesForPlatform(browser).isSupported, false);
    expect(textToSpeechCapabilitiesForPlatform(browser).isSupported, false);
    const arm32 = TaskPlatform(operatingSystem: 'android', architecture: 'arm');
    expect(textToSpeechCapabilitiesForPlatform(arm32).isSupported, false);
  });

  test('a browser serves the speech tasks once the web plugin registers', () {
    // TaskPlatform.current on the web.
    const browser = TaskPlatform(
      operatingSystem: 'web',
      architecture: 'unknown',
    );
    expect(audioTranscriberCapabilitiesForPlatform(browser).isSupported, false);
    expect(textToSpeechCapabilitiesForPlatform(browser).isSupported, false);
    audioTranscriberOpener = (_) => throw UnimplementedError();
    addTearDown(() => audioTranscriberOpener = null);
    expect(audioTranscriberCapabilitiesForPlatform(browser).isSupported, true);
    expect(textToSpeechCapabilitiesForPlatform(browser).isSupported, true);
    for (final capabilities in [
      audioTranscriberCapabilitiesForPlatform(browser),
      textToSpeechCapabilitiesForPlatform(browser),
    ]) {
      expect(capabilities.supportedDelegates, {Delegate.cpu});
    }
    expect(
      audioTranscriberCapabilitiesForPlatform(
        browser,
      ).unavailableReasons[Delegate.gpu],
      contains('no WebGPU adapter'),
    );
    // A software adapter gets the same answer.
    const software = TaskPlatform(
      operatingSystem: 'web',
      architecture: 'unknown',
      gpu: 'WebGPU google swiftshader',
    );
    expect(
      audioTranscriberCapabilitiesForPlatform(software).supportedDelegates,
      {Delegate.cpu},
    );
    const hardware = TaskPlatform(
      operatingSystem: 'web',
      architecture: 'unknown',
      gpu: 'WebGPU apple metal-3',
      browserEngine: BrowserEngine.blink,
    );
    expect(textToSpeechCapabilitiesForPlatform(hardware).supportedDelegates, {
      Delegate.cpu,
    });
    expect(
      textToSpeechCapabilitiesForPlatform(
        hardware,
      ).unavailableReasons[Delegate.gpu],
      contains('in a browser yet'),
    );
  });

  group('the browser GPU delegate, offered only where a test proved it', () {
    setUp(() {
      audioTranscriberOpener = (_) => throw UnimplementedError();
      browserOnMac = true;
      addTearDown(() {
        audioTranscriberOpener = null;
        browserOnMac = false;
      });
    });

    TaskCapabilities on(String? gpu, BrowserEngine? engine) =>
        audioTranscriberCapabilitiesForPlatform(
          TaskPlatform(
            operatingSystem: 'web',
            architecture: 'unknown',
            gpu: gpu,
            browserEngine: engine,
          ),
        );

    test("Chromium and WebKit on a Mac's Apple adapter", () {
      for (final (gpu, engine) in const [
        ('WebGPU apple metal-3', BrowserEngine.blink),
        ('WebGPU apple apple apple', BrowserEngine.webkit),
      ]) {
        expect(on(gpu, engine).supportedDelegates, {
          Delegate.cpu,
          Delegate.gpu,
        }, reason: gpu);
      }
    });

    test('no other browser or adapter, and the refusal says why', () {
      for (final (gpu, engine) in const [
        ('WebGPU apple metal-3', BrowserEngine.gecko),
        ('WebGPU apple metal-3', null),
        ('WebGPU intel gen-9', BrowserEngine.blink),
        ('WebGPU amd gcn-5', BrowserEngine.webkit),
        ('WebGPU nvidia ga100', BrowserEngine.blink),
        ('WebGPU applesauce metal-3', BrowserEngine.blink),
      ]) {
        final capabilities = on(gpu, engine);
        expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: gpu);
        final why = capabilities.unavailableReasons[Delegate.gpu];
        expect(why, contains('a test proved'), reason: gpu);
        expect(why, contains("a Mac's Apple adapter"), reason: gpu);
        expect(why, contains(gpu), reason: gpu);
      }
    });

    test("a phone or tablet naming a Mac's adapter", () {
      browserOnMac = false;
      for (final (gpu, engine) in const [
        ('WebGPU apple metal-3', BrowserEngine.blink),
        ('WebGPU apple apple apple', BrowserEngine.webkit),
        ('WebGPU nvidia ga100', BrowserEngine.blink),
        ('WebGPU qualcomm adreno-7xx', BrowserEngine.blink),
      ]) {
        final capabilities = on(gpu, engine);
        expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: gpu);
        expect(
          capabilities.unavailableReasons[Delegate.gpu],
          contains('a test proved'),
          reason: gpu,
        );
      }
    });

    test('a Mac without a hardware adapter', () {
      for (final gpu in const [null, 'WebGPU apple swiftshader']) {
        final capabilities = on(gpu, BrowserEngine.blink);
        expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: gpu);
        expect(
          capabilities.unavailableReasons[Delegate.gpu],
          contains('needs a hardware WebGPU adapter'),
          reason: gpu,
        );
      }
    });
  });

  test('UTF-8 offsets become UTF-16 indices', () {
    const text = 'Café 😀 done';
    final indices = utf16Indices(text);
    expect(indices, hasLength(utf8.encode(text).length + 1));
    int at(String prefix) => indices[utf8.encode(prefix).length];
    expect(at('Caf'), 3);
    expect(at('Café'), 4);
    expect(at('Café 😀'), 'Café 😀'.length);
    expect(at(text), text.length);
  });

  test('struct layouts match the 1.2.3 C headers', () {
    expect(sizeOf<asr.MpAudioTranscriberOptions>(), 112);
    expect(sizeOf<asr.MpTranscriptionSegment>(), 32);
    expect(sizeOf<asr.MpAudioTranscriberResult>(), 16);
    expect(sizeOf<tts.MpTextToSpeechOptions>(), 112);
    expect(sizeOf<tts.MpTextToSpeechSynthesisOptions>(), 16);
    expect(sizeOf<tts.MpTextToSpeechVoiceInfo>(), 32);
    expect(sizeOf<tts.MpTextToSpeechVoiceList>(), 16);
    expect(sizeOf<tts.MpTextToSpeechWordTimestamp>(), 24);
    expect(sizeOf<tts.MpTextToSpeechAudioResult>(), 40);
  });
}

/// Why a test needing [path] skips, or null when it runs: always on a CI job
/// that downloads [name], where a missing file fails the test instead.
String? _missing(String model, String path, String name) =>
    File(path).existsSync() || _requiredModels.contains(name)
    ? null
    : 'No $model model at $path; run dart tool/download_models.dart $name.';

/// Google's outcomes on this host for a model path that is no model, from
/// tool/generate_speech_error_reference.py, or null where none was made: the
/// checked-in one is the Mac's, and Google's status differs by OS.
Map<String, dynamic>? _errorReference() {
  const own = 'MEDIAPIPE_SPEECH_ERROR_REFERENCE_DIR';
  final environment = Platform.environment.containsKey(own)
      ? own
      : 'MEDIAPIPE_SPEECH_REFERENCE_DIR';
  if (!Platform.isMacOS && !Platform.environment.containsKey(environment)) {
    return null;
  }
  return loadSameHostReference(
    'official_speech_error_reference.json',
    prefix: 'error_',
    cases: 'cases',
    environment: environment,
    wheel: releaseReferenceWheel,
  );
}

/// The path [outcome] was captured with, made under [root] as the generator
/// made it.
Future<String> _noModel(Directory root, Map<String, dynamic> outcome) async {
  final file = outcome['file'] as String;
  final kind = outcome['kind'] as String;
  if (kind == 'missing') return '/nonexistent/$file';
  final separator = Platform.pathSeparator;
  final path = '${root.path}$separator$kind$separator$file';
  if (kind == 'directory') {
    await Directory(path).create(recursive: true);
  } else {
    await File(path).create(recursive: true);
    await File(path).writeAsString(_notAModel);
  }
  return path;
}

/// The bytes of the generator's file that is not a model.
const _notAModel = 'not a model';

/// Google's status and message, with the path in place of `{path}`.
Matcher _googleError(Map<String, dynamic> outcome, String path) =>
    isA<TaskException>()
        .having((error) => error.statusCode, 'statusCode', outcome['status'])
        .having(
          (error) => error.message,
          'message',
          (outcome['message'] as String).replaceAll('{path}', path),
        )
        .having((error) => error.gpuUnavailable, 'gpuUnavailable', false);

/// The package's NOT_FOUND on Linux for a Text to Speech model path that is
/// no file.
Matcher _noModelFile(String path) => isA<TaskException>()
    .having((error) => error.statusCode, 'statusCode', 5)
    .having((error) => error.message, 'message', contains(path))
    .having((error) => error.gpuUnavailable, 'gpuUnavailable', false);

/// [clip] [copies] times, with [gapFrames] of silence between two copies: the
/// reference's long input, built as tool/generate_speech_reference.py builds
/// it.
AudioData _joined(
  AudioData clip, {
  required int copies,
  required int gapFrames,
}) {
  final length = clip.samples.length;
  final samples = Float32List(copies * length + (copies - 1) * gapFrames);
  for (var copy = 0; copy < copies; copy++) {
    samples.setAll(copy * (length + gapFrames), clip.samples);
  }
  return AudioData(samples: samples, sampleRate: clip.sampleRate);
}

/// What a stream past the model's 5 s window must show, beyond matching
/// Google's segments: its final segments tile the input from 0 to about its
/// end ([durationMs]) in order, and are the [whole] input's segments; each
/// interim segment is replaced by a final one from the same time; and in
/// blocks ([streamed]) segments are finalized before the stream finishes.
/// Google's segments repeat words at the window seams ("Send a text to",
/// then "text Mike. I'll be home"), so the text is the reference's, word for
/// word.
void _expectWindowed(
  List<List<Map<String, Object>>> calls,
  List<Map<String, Object>> finish, {
  required List whole,
  required bool streamed,
  required double durationMs,
}) {
  final segments = [...calls.expand((call) => call), ...finish];
  final finals = [
    for (final segment in segments)
      if (segment['is_final'] == true) segment,
  ];
  expect(finals, whole, reason: 'the final segments are the whole input\'s');
  expect(finals.length, greaterThan(1));
  expect(finals.first['from_ms'], 0);
  for (final (i, segment) in finals.indexed) {
    expect(
      segment['to_ms'] as int,
      greaterThan(segment['from_ms'] as int),
      reason: 'segment $i',
    );
    if (i > 0) {
      expect(segment['from_ms'], finals[i - 1]['to_ms'], reason: 'segment $i');
    }
  }
  expect(finals.last['to_ms'] as int, closeTo(durationMs, 100));
  expect(
    finish.where((segment) => segment['is_final'] != true),
    isEmpty,
    reason: 'the finish leaves nothing interim',
  );
  for (final (i, segment) in segments.indexed) {
    if (segment['is_final'] == true) continue;
    expect(
      segments
          .skip(i + 1)
          .where(
            (later) =>
                later['is_final'] == true &&
                later['from_ms'] == segment['from_ms'],
          ),
      hasLength(1),
      reason: 'interim segment $i is replaced',
    );
  }
  if (streamed) {
    expect(
      calls.expand((call) => call).where((s) => s['is_final'] == true),
      isNotEmpty,
      reason: 'segments are finalized before the stream finishes',
    );
  }
}

List<Map<String, Object>> _segments(AudioTranscriberResult result) => [
  for (final segment in result.segments)
    {
      'transcript': segment.transcript,
      'is_final': segment.isFinal,
      'from_ms': segment.fromTimestampMilliseconds,
      'to_ms': segment.toTimestampMilliseconds,
    },
];

/// [result] against Google's: the same length and rate, the same words at
/// the same places in [text] (Google's UTF-8 byte offsets, which the package
/// turns into UTF-16 indices), and the same level in every window.
void _expectAudio(
  TextToSpeechResult result,
  String text,
  Map<String, dynamic> expected, {
  double secondsDelta = _secondsDelta,
  double levelDelta = _levelDelta,
}) {
  expect(result.samples, hasLength(expected['samples']));
  expect(result.sampleRateHz, expected['sample_rate_hz']);
  final words = (expected['words'] as List).cast<List>();
  expect(result.wordTimestamps, hasLength(words.length));
  for (final (i, word) in result.wordTimestamps.indexed) {
    final [
      String name,
      int startByte,
      int endByte,
      num startSeconds,
      num endSeconds,
    ] = words[i];
    expect(word.word, name);
    expect(text.substring(word.start, word.end), name);
    expect(utf8.encode(text.substring(0, word.start)), hasLength(startByte));
    expect(utf8.encode(text.substring(0, word.end)), hasLength(endByte));
    expect(word.startSeconds, closeTo(startSeconds, secondsDelta));
    expect(word.endSeconds, closeTo(endSeconds, secondsDelta));
  }
  final peak = result.samples.fold(0.0, (m, s) => math.max(m, s.abs()));
  expect(peak, closeTo(expected['peak'] as num, levelDelta));
  final envelope = (expected['envelope'] as List).cast<num>();
  final window = (result.sampleRateHz * 0.1).round();
  expect((result.samples.length + window - 1) ~/ window, envelope.length);
  for (final (i, level) in envelope.indexed) {
    final part = result.samples.sublist(
      i * window,
      math.min((i + 1) * window, result.samples.length),
    );
    final rms = math.sqrt(
      part.fold(0.0, (sum, s) => sum + s * s) / part.length,
    );
    expect(rms, closeTo(level, levelDelta), reason: 'window $i');
  }
}

/// [_expectAudio] for PocketTTS, within the spread of Google's own answers
/// on Linux.
void _expectPocketTtsAudio(
  TextToSpeechResult result,
  String text,
  Map<String, dynamic> expected,
) => _expectAudio(
  result,
  text,
  expected,
  secondsDelta: _pocketTtsSecondsDelta,
  levelDelta: _pocketTtsLevelDelta,
);

/// [check] against Google's [first] answer, else against its [alternatives]:
/// where Google's own tasks answer the same input differently, as PocketTTS's
/// do on Linux, tool/generate_pocket_tts_reference.py keeps each distinct
/// answer its tasks gave, and the package's must match one of them.
void _expectOneOfGoogles<T>(
  T first,
  List? alternatives,
  void Function(T answer) check,
) {
  if (alternatives == null) return check(first);
  final failures = <String>[];
  for (final answer in [first, ...alternatives.cast<T>()]) {
    try {
      return check(answer);
    } on TestFailure catch (failure) {
      failures.add(failure.message ?? '$failure');
    }
  }
  fail(
    'Matches none of Google\'s ${failures.length} answers:\n'
    '${failures.join('\n')}',
  );
}

/// The RMS of [length] samples from [start].
double _windowRms(Float32List samples, int start, int length) {
  var sum = 0.0;
  for (var i = start; i < start + length; i++) {
    sum += samples[i] * samples[i];
  }
  return math.sqrt(sum / length);
}

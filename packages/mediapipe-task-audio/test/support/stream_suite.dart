/// The audio stream's contract through the public class, on a fake backend
/// installed through the platform interface: the browser's clips backend,
/// which the stream emulates on. Shared by the VM suite and the browser
/// suite, which runs it as JavaScript and as WebAssembly, since the clock's
/// arithmetic must hold with JavaScript numbers.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_audio/platform_interface.dart';
import 'package:mediapipe_audio/src/stream/checks.dart';
import 'package:mediapipe_audio/src/stream/model_specs.dart';
import 'package:mediapipe_audio/src/stream/results.dart';
import 'package:test/test.dart';

import 'audio_model.dart';

/// Google's browser task, faked. A clip's frames carry their index in the
/// stream as their value, so each result names the frames it was given.
final class FakeClips implements AudioTaskBackend {
  final clips = <(Float32List, double)>[];

  /// Chunks clips mode returns per clip: Google's returns two for a window at
  /// any rate but the model's.
  var chunks = 1;

  /// The clip, counted from 1, that fails as Google's runtime would.
  int? failAt;

  /// Holds every clip until it completes.
  Completer<void>? gate;
  var disposed = false;

  @override
  Future<List<Object?>> classify(Float32List samples, double rate) async {
    clips.add((samples, rate));
    final count = clips.length;
    await gate?.future;
    if (failAt == count) throw const TaskException('Fake graph failure.');
    return [
      for (var chunk = 0; chunk < chunks; chunk++)
        {
          'timestampMs': chunk * 975,
          'classifications': [
            {
              'headIndex': 0,
              'headName': 'fake',
              'categories': [
                {
                  'index': chunk,
                  'score': 0.5,
                  'categoryName':
                      '${samples.first.toInt()}-${samples.last.toInt()}',
                  'displayName': '',
                },
              ],
            },
          ],
        },
    ];
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// [frames] frames of [channels] values from frame [first] on, each value
/// the frame's index in the stream.
AudioData frames(
  int first,
  int frames, {
  double rate = 8000,
  int channels = 1,
}) {
  final samples = Float32List(frames * channels);
  for (var i = 0; i < frames; i++) {
    for (var c = 0; c < channels; c++) {
      samples[i * channels + c] = (first + i).toDouble();
    }
  }
  return AudioData(samples: samples, sampleRate: rate, channels: channels);
}

/// Every result's timestamp and the frames its window held.
List<(int, String)> heard(List<AudioClassifierResult> results) => [
  for (final result in results)
    (
      result.timestampMilliseconds,
      result.classifications.single.categories.single.categoryName!,
    ),
];

Matcher _argument(String name, String message) => throwsA(
  isA<ArgumentError>()
      .having((e) => e.name, 'name', name)
      .having((e) => e.message, 'message', message),
);

Matcher _state(String message) =>
    throwsA(isA<StateError>().having((e) => e.message, 'message', message));

const _timestampRule =
    'Must be nonnegative, strictly increasing and at most 9007199254740';

void streamSuite() {
  final clipBackends = <FakeClips>[];

  setUp(() {
    clipBackends.clear();
    audioTaskBackendFactory = (_) async {
      final backend = FakeClips();
      clipBackends.add(backend);
      return backend;
    };
  });
  tearDown(() => audioTaskBackendFactory = null);

  /// A stream task on a model reading [window] frames of [channels] values
  /// at [rate]; 8 frames at 8 kHz make windows one millisecond apart.
  Future<AudioClassifier> open({
    int window = 8,
    int rate = 8000,
    int channels = 1,
  }) async {
    final task = await AudioClassifier.create(
      AudioClassifierOptions(
        modelBytes: audioModel(window: window, rate: rate, channels: channels),
        runningMode: AudioRunningMode.audioStream,
      ),
    );
    addTearDown(task.dispose);
    return task;
  }

  /// Listens, and returns what arrives and when the stream ends.
  (List<AudioClassifierResult>, List<Object>, Future<void>) listen(
    AudioClassifier task,
  ) {
    final results = <AudioClassifierResult>[];
    final errors = <Object>[];
    final done = Completer<void>();
    task.results.listen(
      results.add,
      onError: errors.add,
      onDone: done.complete,
    );
    return (results, errors, done.future);
  }

  group('listening', () {
    test(
      'a block before a listener throws, as does a second listener',
      () async {
        final task = await open();
        expect(
          () => task.classifyAsync(frames(0, 8), timestampMilliseconds: 0),
          _state(
            'Listen to AudioClassifier.results before submitting the first '
            'block.',
          ),
        );
        task.results.listen((_) {});
        expect(() => task.results.listen((_) {}), throwsStateError);
        // The refused block reserved nothing.
        task.classifyAsync(frames(0, 8), timestampMilliseconds: 0);
      },
    );

    test('pausing buffers, and resuming delivers in order', () async {
      final task = await open();
      final arrived = <AudioClassifierResult>[];
      final subscription = task.results.listen(arrived.add)..pause();
      task.classifyAsync(frames(0, 24), timestampMilliseconds: 0);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(clipBackends.single.clips, hasLength(3));
      expect(arrived, isEmpty);
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(heard(arrived), [(0, '0-7'), (1, '8-15'), (2, '16-23')]);
    });

    test('cancelling discards results while blocks go on', () async {
      final task = await open();
      final arrived = <AudioClassifierResult>[];
      final subscription = task.results.listen(arrived.add);
      task.classifyAsync(frames(0, 8), timestampMilliseconds: 0);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      task.classifyAsync(frames(8, 16), timestampMilliseconds: 1);
      await task.dispose();
      expect(heard(arrived), [(0, '0-7')]);
      expect(clipBackends.single.clips, hasLength(3));
    });
  });

  group('checks, in the contract\'s order', () {
    test('the first block fixes the rate; a change reserves nothing', () async {
      final task = await open();
      listen(task);
      task.classifyAsync(frames(0, 4), timestampMilliseconds: 0);
      expect(
        () => task.classifyAsync(
          frames(4, 4, rate: 16000),
          timestampMilliseconds: 1,
        ),
        _argument(
          'sampleRate',
          'The stream runs at 8000.0 Hz, fixed by its first block',
        ),
      );
      task.classifyAsync(frames(4, 4), timestampMilliseconds: 1);
    });

    test('a mono model takes any channels, block by block', () async {
      final task = await open();
      final (arrived, _, done) = listen(task);
      task
        ..classifyAsync(frames(0, 4, channels: 2), timestampMilliseconds: 0)
        ..classifyAsync(frames(4, 2, channels: 3), timestampMilliseconds: 1)
        ..classifyAsync(frames(6, 2), timestampMilliseconds: 2);
      await task.dispose();
      await done;
      // Averaged to one channel, as clips mode averages in browsers.
      expect(heard(arrived), [(0, '0-7')]);
    });

    test('another model requires its own channel count', () async {
      final task = await open(channels: 3);
      listen(task);
      expect(
        () => task.classifyAsync(
          frames(0, 8, channels: 2),
          timestampMilliseconds: 0,
        ),
        _argument('channels', 'The model requires 3 channel(s)'),
      );
      task.classifyAsync(frames(0, 8, channels: 3), timestampMilliseconds: 0);
    });

    test(
      'timestamps are nonnegative, increasing and within the limit',
      () async {
        final task = await open();
        listen(task);
        expect(
          () => task.classifyAsync(frames(0, 1), timestampMilliseconds: -1),
          _argument('timestampMilliseconds', _timestampRule),
        );
        expect(
          () => task.classifyAsync(
            frames(0, 1),
            timestampMilliseconds: 9007199254741,
          ),
          _argument('timestampMilliseconds', _timestampRule),
        );
        task.classifyAsync(frames(0, 1), timestampMilliseconds: 10);
        for (final timestamp in [10, 9]) {
          expect(
            () => task.classifyAsync(
              frames(1, 1),
              timestampMilliseconds: timestamp,
            ),
            _argument('timestampMilliseconds', _timestampRule),
          );
        }
        task.classifyAsync(frames(1, 1), timestampMilliseconds: 9007199254740);
      },
    );

    test('each mode refuses the other\'s calls', () async {
      final stream = await open();
      await expectLater(
        stream.classify(frames(0, 8)),
        _state(
          'AudioClassifier was created in audioStream mode; this method '
          'requires audioClips mode.',
        ),
      );
      final clips = await AudioClassifier.create(
        AudioClassifierOptions(
          modelBytes: audioModel(window: 8, rate: 8000, channels: 1),
        ),
      );
      addTearDown(clips.dispose);
      const message =
          'AudioClassifier was created in audioClips mode; this method '
          'requires audioStream mode.';
      expect(() => clips.results, _state(message));
      expect(
        () => clips.classifyAsync(frames(0, 8), timestampMilliseconds: 0),
        _state(message),
      );
      expect(clips.runningMode, AudioRunningMode.audioClips);
      expect(stream.runningMode, AudioRunningMode.audioStream);
    });

    test('every call after dispose throws', () async {
      final task = await open();
      listen(task);
      await task.dispose();
      expect(
        () => task.classifyAsync(frames(0, 8), timestampMilliseconds: 0),
        _state('AudioClassifier has been disposed.'),
      );
      await expectLater(
        task.classify(frames(0, 8)),
        _state('AudioClassifier has been disposed.'),
      );
    });
  });

  group('the emulation', () {
    test('frames windows across blocks of any length', () async {
      final task = await open();
      final (arrived, _, done) = listen(task);
      var at = 0, timestamp = 100;
      // Blocks of three frames, of one frame, and of three windows.
      for (final size in [3, 3, 3, 1, 1, 1, 1, 1, 24, 4]) {
        task.classifyAsync(frames(at, size), timestampMilliseconds: timestamp);
        at += size;
        timestamp += 7;
      }
      await task.dispose();
      await done;
      // The first block's timestamp, then a window a millisecond; the tail
      // (frames 40 and 41) where its audio starts.
      expect(heard(arrived), [
        (100, '0-7'),
        (101, '8-15'),
        (102, '16-23'),
        (103, '24-31'),
        (104, '32-39'),
        (105, '40-41'),
      ]);
      expect(clipBackends.single.disposed, isTrue);
    });

    test(
      'an empty block is accepted, reserves its timestamp, and goes nowhere',
      () async {
        final task = await open();
        final (arrived, _, done) = listen(task);
        task.classifyAsync(
          AudioData(samples: Float32List(0), sampleRate: 8000),
          timestampMilliseconds: 50,
        );
        expect(
          () => task.classifyAsync(frames(0, 8), timestampMilliseconds: 50),
          throwsArgumentError,
        );
        task.classifyAsync(frames(0, 8), timestampMilliseconds: 60);
        await task.dispose();
        await done;
        // The stream starts at the first block that holds samples.
        expect(heard(arrived), [(60, '0-7')]);
        expect(clipBackends.single.clips, hasLength(1));
      },
    );

    test(
      'at 44.1 kHz a window is 42,997.5 frames, and only the first chunk counts',
      () async {
        final task = await open(window: 15600, rate: 16000);
        final (arrived, _, done) = listen(task);
        clipBackends.single.chunks = 2;
        task.classifyAsync(
          frames(0, 128993 + 10, rate: 44100),
          timestampMilliseconds: 5000,
        );
        await task.dispose();
        await done;
        expect(heard(arrived), [
          (5000, '0-42997'),
          (5975, '42997-85994'),
          (6950, '85995-128992'),
          // The tail: what remains from window 3's start, floor(3 * 42997.5).
          (7925, '128992-129002'),
        ]);
        expect(clipBackends.single.clips.first.$2, 44100);
      },
    );

    test('nothing remains, no tail', () async {
      final task = await open();
      final (arrived, _, done) = listen(task);
      task.classifyAsync(frames(0, 16), timestampMilliseconds: 0);
      await task.dispose();
      await done;
      expect(heard(arrived), [(0, '0-7'), (1, '8-15')]);
    });

    test('Google\'s clock holds with JavaScript numbers', () {
      final checks = AudioStreamChecks(AudioRunningMode.audioStream)
        ..specs = const AudioModelSpecs(
          windowSamples: 15600,
          sampleRate: 16000,
          channels: 1,
        );
      final clock = AudioStreamResults(checks)..blockSent(9007199254740);
      expect(checks.specs.stepMicroseconds, 975000);
      expect(clock.windowTimestamp(0), 9007199254740);
      expect(clock.windowTimestamp(3), 9007199254740 + 2925);
      // A year of windows: 975,000 microseconds times 32 million.
      expect(clock.windowTimestamp(32345000), 9007199254740 + 31536375000);
      // 44.1 kHz windows of 1,000 frames: 22,675.73... microseconds, which
      // Google rounds to 22,676 before it adds them.
      final rounded = AudioStreamChecks(AudioRunningMode.audioStream)
        ..specs = const AudioModelSpecs(
          windowSamples: 1000,
          sampleRate: 44100,
          channels: 1,
        );
      expect(rounded.specs.stepMicroseconds, 22676);
      expect(
        (AudioStreamResults(rounded)..blockSent(0)).windowTimestamp(7),
        158,
      );
    });
  });

  group('failures', () {
    test('a failed window ends the stream once and poisons the task', () async {
      final task = await open();
      final (arrived, errors, done) = listen(task);
      clipBackends.single.failAt = 2;
      task.classifyAsync(frames(0, 32), timestampMilliseconds: 0);
      await done;
      expect(heard(arrived), [(0, '0-7')]);
      expect(errors, [isA<TaskException>()]);
      final failure = errors.single;
      expect(
        () => task.classifyAsync(frames(32, 8), timestampMilliseconds: 9),
        throwsA(same(failure)),
      );
      // Disposal still closes Google's task, and runs no more windows.
      await task.dispose();
      expect(clipBackends.single.disposed, isTrue);
      expect(clipBackends.single.clips, hasLength(2));
    });

    test(
      'dispose twice is one disposal, and a paused listener does not hold it',
      () async {
        final task = await open();
        final subscription = task.results.listen((_) {})..pause();
        task.classifyAsync(frames(0, 12), timestampMilliseconds: 0);
        final first = task.dispose();
        expect(identical(first, task.dispose()), isTrue);
        await first;
        await subscription.cancel();
      },
    );
  });

  group('the model\'s audio input', () {
    test('is read from the model, inline or by offset', () {
      for (final byOffset in [false, true]) {
        expect(
          AudioModelSpecs.read(
            audioModel(
              window: 8,
              rate: 8000,
              channels: 3,
              metadataByOffset: byOffset,
            ),
          ),
          const AudioModelSpecs(
            windowSamples: 8,
            sampleRate: 8000,
            channels: 3,
          ),
        );
      }
    });

    test('names what is missing', () {
      Matcher missing(String what) => throwsA(
        isA<FormatException>().having((e) => e.message, 'message', what),
      );
      final model = audioModel(window: 8, rate: 8000, channels: 1);
      expect(
        () => AudioModelSpecs.read(Uint8List.sublistView(model, 0, 40)),
        missing('the model is truncated'),
      );
      expect(
        () => AudioModelSpecs.read(
          audioModel(
            window: 8,
            rate: 8000,
            channels: 1,
            content: ModelContent.noMetadata,
          ),
        ),
        missing('missing TFLITE_METADATA'),
      );
      expect(
        () => AudioModelSpecs.read(
          audioModel(
            window: 8,
            rate: 8000,
            channels: 1,
            content: ModelContent.image,
          ),
        ),
        missing("missing the input's AudioProperties (it has ImageProperties)"),
      );
      expect(
        () => AudioModelSpecs.read(
          audioModel(
            window: 8,
            rate: 8000,
            channels: 1,
            content: ModelContent.none,
          ),
        ),
        missing("missing the input's content"),
      );
    });

    test(
      'a model Google accepted but that cannot be read fails creation',
      () async {
        await expectLater(
          AudioClassifier.create(
            AudioClassifierOptions(
              modelBytes: audioModel(
                window: 8,
                rate: 8000,
                channels: 1,
                content: ModelContent.noMetadata,
              ),
              runningMode: AudioRunningMode.audioStream,
            ),
          ),
          throwsA(
            isA<TaskException>().having(
              (e) => e.message,
              'message',
              "Cannot read the model's audio input: missing TFLITE_METADATA.",
            ),
          ),
        );
        expect(clipBackends.single.disposed, isTrue);
      },
    );
  });
}

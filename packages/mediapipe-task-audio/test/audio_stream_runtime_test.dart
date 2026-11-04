import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_audio/src/stream/checks.dart';
import 'package:mediapipe_audio/src/stream/emulation.dart';
import 'package:mediapipe_audio/src/stream/model_specs.dart';
import 'package:mediapipe_audio/src/stream/results.dart';
import 'package:mediapipe_audio/src/third_party/mediapipe/audio_stream_bindings.dart'
    as bridge;
import 'package:test/test.dart';
import 'support/same_host_reference.dart';

/// Audio stream mode on Google's native runtime: every case against Google's
/// own stream on this host, the tail proven to be Google's flush, the
/// emulation at the model's rate equal to the native stream to the last bit,
/// and the stream's lifetime.
const _fixtures = 'test/fixtures';
const _model = 'models/yamnet.tflite';

/// The same runtime, model and samples as Google's reference, so scores agree
/// to rounding (the reference rounds to six places), as in clips mode.
const _scoreDelta = 1e-5;

/// What Google stamps the tail with: Timestamp::Max() in milliseconds.
const _googleTail = 9223372036854775;

void main() {
  final reference = loadSameHostReference(
    'official_stream_reference.json',
    prefix: 'stream_',
    cases: 'cases',
  );
  final cases = (reference['cases'] as Map).cast<String, Map>();
  final model = File(_model).readAsBytesSync();
  final specs = AudioModelSpecs.read(model);
  final googleTimestamps = <int>[];

  setUpAll(() {
    expect(sha256.convert(model).toString(), AudioModels.yamnet.sha256);
    expect(reference['model_sha256'], AudioModels.yamnet.sha256);
    debugGoogleStreamTimestamp = googleTimestamps.add;
  });
  tearDownAll(() => debugGoogleStreamTimestamp = null);
  setUp(googleTimestamps.clear);

  for (final MapEntry(key: name, value: expected) in cases.entries) {
    test('$name matches Google\'s stream, window by window', () async {
      final task = await _open(maxResults: 3);
      final run = await _run(task, expected);
      final want = (expected['results'] as List).cast<Map>();
      expect(run.results, hasLength(want.length));
      // Google's own stamps, the tail's sentinel included: no code of ours
      // produces it, so a sentinel here proves the result is Google's flush.
      expect(googleTimestamps, [for (final r in want) r['timestamp_ms']]);
      final first = expected['first_timestamp_ms'] as int;
      final clock = _clock(specs, first);
      for (final (i, result) in run.results.indexed) {
        final raw = want[i]['timestamp_ms'] as int;
        if (raw != _googleTail) {
          // Every full window: Google's stamp equals the Dart clock's.
          expect(raw, clock.windowTimestamp(i), reason: '$name[$i]');
        }
        // The tail gets where its audio starts, as clips mode reports it.
        expect(
          result.timestampMilliseconds,
          raw == _googleTail ? clock.windowTimestamp(i) : raw,
          reason: '$name[$i]',
        );
        expect(i >= run.beforeDispose, want[i]['during_close'], reason: name);
        _expectTop(result, want[i]['top'] as List, '$name[$i]');
      }
    });
  }

  test(
    'the lone half second yields nothing until dispose, then the tail',
    () async {
      final task = await _open(maxResults: 3);
      final run = await _run(task, cases['lone-half-second']!);
      expect(run.beforeDispose, 0);
      expect(run.results, hasLength(1));
      expect(googleTimestamps, [_googleTail]);
      expect(run.results.single.timestampMilliseconds, 0);
    },
  );

  test(
    'the emulation at the model\'s rate is Google\'s stream, to the bit',
    () async {
      final clips = await AudioClassifier.create(
        AudioClassifierOptions(modelPath: _model),
      );
      addTearDown(clips.dispose);
      var largest = 0.0;
      var values = 0;
      final oracleCases = {
        for (final MapEntry(key: name, value: spec) in cases.entries)
          if (spec['rate'] == specs.sampleRate) name: spec,
        // Google's buffer is fed one sample at a time: a timestamp bound with
        // no packet would reach Google's converter, which reads the packet
        // unchecked.
        'one-sample-blocks': {
          'clip': 'speech_16000_hz_mono.wav',
          'frames': 16000,
          'rate': 16000,
          'channels': 1,
          'block_frames': 1,
          'first_timestamp_ms': 0,
        },
      };
      for (final MapEntry(key: name, value: spec) in oracleCases.entries) {
        final task = await _open();
        final native = (await _run(task, spec)).results;
        final emulated = await _emulate(specs, spec, (samples, rate, channels) {
          return clips.classify(
            AudioData(samples: samples, sampleRate: rate, channels: channels),
          );
        });
        expect(native, hasLength(emulated.length), reason: name);
        for (final (i, result) in native.indexed) {
          final other = emulated[i];
          expect(
            result.timestampMilliseconds,
            other.timestampMilliseconds,
            reason: '$name[$i]',
          );
          final mine = {
            for (final c in result.classifications.single.categories)
              c.index: c.score,
          };
          final theirs = {
            for (final c in other.classifications.single.categories)
              c.index: c.score,
          };
          expect(mine.keys.toSet(), theirs.keys.toSet(), reason: '$name[$i]');
          for (final MapEntry(key: index, value: score) in mine.entries) {
            largest = math.max(largest, (score - theirs[index]!).abs());
            values++;
          }
        }
        if (name == 'one-sample-blocks') {
          expect(native, hasLength(2));
          expect(native.first.timestampMilliseconds, 0);
        }
      }
      // ignore: avoid_print
      print('AUDIO_STREAM_ORACLE $values values, max $largest');
      // At the model's rate no resampler runs, so both feed the model the same
      // floats and the same zero padding, in the same library.
      expect(largest, 0.0);
      expect(values, greaterThan(0));
    },
  );

  test('refusals stay in Dart and the stream goes on', () async {
    final task = await _open(maxResults: 3);
    final spec = cases['speech-100ms']!;
    final arrived = <AudioClassifierResult>[];
    final done = Completer<void>();
    task.results.listen(arrived.add, onDone: done.complete);
    final blocks = _blocks(spec).toList();
    for (final (i, (block, timestamp)) in blocks.indexed) {
      if (i == 5) {
        expect(
          () => task.classifyAsync(
            AudioData(samples: Float32List(4800), sampleRate: 48000),
            timestampMilliseconds: timestamp,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'The stream runs at 16000.0 Hz, fixed by its first block',
            ),
          ),
        );
        // The previous block's timestamp again: refused, in Dart.
        expect(
          () => task.classifyAsync(
            block,
            timestampMilliseconds: blocks[i - 1].$2,
          ),
          throwsArgumentError,
        );
      }
      task.classifyAsync(block, timestampMilliseconds: timestamp);
    }
    await task.dispose();
    await done.future;
    final want = (spec['results'] as List).cast<Map>();
    expect(arrived, hasLength(want.length));
    for (final (i, result) in arrived.indexed) {
      _expectTop(result, want[i]['top'] as List, 'refusals[$i]');
    }
  });

  test('two streams at once keep their results apart', () async {
    final speech = cases['speech-100ms']!, resampled = cases['speech-48k']!;
    final a = await _open(maxResults: 3), b = await _open(maxResults: 3);
    final heardA = <AudioClassifierResult>[],
        heardB = <AudioClassifierResult>[];
    final doneA = Completer<void>(), doneB = Completer<void>();
    a.results.listen(heardA.add, onDone: doneA.complete);
    b.results.listen(heardB.add, onDone: doneB.complete);
    final blocksA = _blocks(speech).toList(),
        blocksB = _blocks(resampled).toList();
    for (var i = 0; i < math.max(blocksA.length, blocksB.length); i++) {
      if (i < blocksA.length) {
        a.classifyAsync(blocksA[i].$1, timestampMilliseconds: blocksA[i].$2);
      }
      if (i < blocksB.length) {
        b.classifyAsync(blocksB[i].$1, timestampMilliseconds: blocksB[i].$2);
      }
    }
    await Future.wait([a.dispose(), b.dispose(), doneA.future, doneB.future]);
    for (final (heard, spec) in [(heardA, speech), (heardB, resampled)]) {
      final want = (spec['results'] as List).cast<Map>();
      expect(heard, hasLength(want.length));
      for (final (i, result) in heard.indexed) {
        _expectTop(result, want[i]['top'] as List, '${spec['clip']}[$i]');
      }
    }
  });

  test(
    'a stream disposed with blocks still queued delivers every result first',
    () async {
      final task = await _open(maxResults: 3);
      final spec = cases['speech-100ms']!;
      final arrived = <AudioClassifierResult>[];
      final done = Completer<void>();
      task.results.listen(arrived.add, onDone: done.complete);
      for (final (block, timestamp) in _blocks(spec)) {
        task.classifyAsync(block, timestampMilliseconds: timestamp);
      }
      final disposing = task.dispose();
      expect(identical(disposing, task.dispose()), isTrue);
      await disposing;
      await done.future;
      expect(arrived.map((r) => r.timestampMilliseconds), [
        0,
        975,
        1950,
        2925,
        3900,
      ]);
      expect(
        () => task.classifyAsync(
          AudioData(samples: Float32List(1600), sampleRate: 16000),
          timestampMilliseconds: 99999,
        ),
        throwsStateError,
      );
    },
  );

  test('no blocks, no results', () async {
    final task = await _open();
    final arrived = <AudioClassifierResult>[];
    final done = Completer<void>();
    task.results.listen(arrived.add, onDone: done.complete);
    task.classifyAsync(
      AudioData(samples: Float32List(0), sampleRate: 16000),
      timestampMilliseconds: 0,
    );
    await task.dispose();
    await done.future;
    expect(arrived, isEmpty);
    expect(googleTimestamps, isEmpty);
  });

  test('64 streams open at once and the 65th is refused', () async {
    final tasks = <AudioClassifier>[];
    try {
      for (var i = 0; i < bridge.streamSlots; i++) {
        tasks.add(await _open());
      }
      await expectLater(
        _open(),
        throwsA(
          isA<TaskException>().having(
            (e) => e.message,
            'message',
            contains('64 at once'),
          ),
        ),
      );
    } finally {
      await Future.wait([for (final task in tasks) task.dispose()]);
    }
    expect(tasks, hasLength(bridge.streamSlots));
    // Every slot is free again.
    await (await _open()).dispose();
  });

  test('struct layouts match the stream bridge', () {
    expect(sizeOf<bridge.MpFlutterAudioCategory>(), 24);
    expect(sizeOf<bridge.MpFlutterAudioHead>(), 24);
    expect(sizeOf<bridge.MpFlutterAudioEvent>(), 40);
  });
}

/// A stream task, disposed when the test ends however it ends: the bridge's
/// slots are shared by the whole process.
Future<AudioClassifier> _open({int maxResults = -1}) async {
  final task = await AudioClassifier.create(
    AudioClassifierOptions(
      modelPath: _model,
      maxResults: maxResults,
      runningMode: AudioRunningMode.audioStream,
    ),
  );
  addTearDown(task.dispose);
  return task;
}

/// A case's audio as the generator builds it: the clip's first frames,
/// copied to every channel.
AudioData _audio(Map spec) {
  final clip = decodeWav(File('$_fixtures/${spec['clip']}').readAsBytesSync());
  final frames = spec['frames'] as int, channels = spec['channels'] as int;
  final samples = Float32List(frames * channels);
  for (var i = 0; i < frames; i++) {
    for (var c = 0; c < channels; c++) {
      samples[i * channels + c] = clip.samples[i];
    }
  }
  return AudioData(
    samples: samples,
    sampleRate: clip.sampleRate,
    channels: channels,
  );
}

/// A case's blocks, each stamped as the generator stamps it: its first
/// frame's time, a millisecond later than the block before where blocks are
/// shorter than a millisecond.
Iterable<(AudioData, int)> _blocks(Map spec) sync* {
  final audio = _audio(spec);
  final rate = audio.sampleRate.toInt();
  final frames = audio.samples.length ~/ audio.channels;
  final size = spec['block_frames'] as int;
  final first = spec['first_timestamp_ms'] as int;
  var previous = first - 1;
  for (var start = 0; start < frames; start += size) {
    final end = math.min(start + size, frames);
    previous = math.max(previous + 1, first + start * 1000 ~/ rate);
    yield (
      AudioData(
        samples: Float32List.sublistView(
          audio.samples,
          start * audio.channels,
          end * audio.channels,
        ),
        sampleRate: audio.sampleRate,
        channels: audio.channels,
      ),
      previous,
    );
  }
}

/// Feeds a case, waits for its full windows as the generator does, then
/// disposes, which flushes the tail.
Future<({List<AudioClassifierResult> results, int beforeDispose})> _run(
  AudioClassifier task,
  Map spec,
) async {
  final arrived = <AudioClassifierResult>[];
  final done = Completer<void>();
  task.results.listen(
    arrived.add,
    onError: (Object error) => done.completeError(error),
    onDone: done.complete,
  );
  for (final (block, timestamp) in _blocks(spec)) {
    task.classifyAsync(block, timestampMilliseconds: timestamp);
  }
  final full =
      (spec['frames'] as int) * 16000 ~/ (spec['rate'] as int) ~/ 15600;
  for (var i = 0; i < 6000 && arrived.length < full; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final before = arrived.length;
  await task.dispose();
  await done.future;
  return (results: arrived, beforeDispose: before);
}

/// The emulation over [classify], fed a case's blocks as the stream is.
Future<List<AudioClassifierResult>> _emulate(
  AudioModelSpecs specs,
  Map spec,
  ClipClassifier classify,
) async {
  final checks = AudioStreamChecks(AudioRunningMode.audioStream)..specs = specs;
  final results = AudioStreamResults(checks);
  final arrived = <AudioClassifierResult>[];
  final done = Completer<void>();
  results.stream.listen(arrived.add, onDone: done.complete);
  final stream = EmulatedAudioStream(specs, classify, results);
  for (final (block, timestamp) in _blocks(spec)) {
    results.blockSent(timestamp);
    stream.add(block);
  }
  await stream.close();
  results.close();
  await done.future;
  return arrived;
}

/// The Dart clock of a stream whose first block is stamped [first].
AudioStreamResults _clock(AudioModelSpecs specs, int first) {
  final checks = AudioStreamChecks(AudioRunningMode.audioStream)..specs = specs;
  return AudioStreamResults(checks)..blockSent(first);
}

/// Google's scores for these names, in its order; categories with equal
/// scores may come in either order.
void _expectTop(AudioClassifierResult result, List want, String where) {
  final categories = result.classifications.single.categories;
  final top = {
    for (final [name as String, score as num] in want.cast<List>())
      name: score.toDouble(),
  };
  expect(
    categories.map((c) => c.categoryName).toSet(),
    top.keys.toSet(),
    reason: where,
  );
  for (final category in categories) {
    expect(
      category.score,
      closeTo(top[category.categoryName]!, _scoreDelta),
      reason: where,
    );
  }
}

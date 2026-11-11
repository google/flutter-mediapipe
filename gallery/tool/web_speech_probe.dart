// The speech tasks through the public Dart API in a browser, for
// tool/browser/test_browser.mjs --suite=speech, which compares every result
// here with Google's JavaScript run on the same page, runtime and inputs.
// A build of its own, as these models are too large for web.yaml's probes.
// ?parakeet=<url> and ?phonon=<url> name where the models are read from, and
// ?runtime=<url> a root serving Google's runtimes, as in the text and audio
// probe. Pinned-model bytes always come from Hugging Face.
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';

@JS('mediapipeSpeechReport')
external set _report(JSAny? value);

/// What test_browser.mjs's counters saw the audio worker do on WebGPU.
extension type _WebGpuWork._(JSObject _) implements JSObject {
  external int get submit;
  external int get pipeline;
}

@JS('webGpuWork')
external _WebGpuWork get _webGpuWork;

/// The chunks test_browser.mjs's counter saw the audio worker send.
@JS('workerChunks')
external int get _workerChunks;

/// The counters at this point, once what the worker posted has arrived.
Future<Map<String, int>> _work() async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return {'submit': _webGpuWork.submit, 'pipeline': _webGpuWork.pipeline};
}

/// Texts and settings, shared with the JavaScript side of the test.
const foxText = 'The quick brown fox jumps over the lazy dog.';
const frenchText = "Bonjour, comment allez-vous aujourd'hui ?";
const streamText =
    'Hello there. This is the second sentence, and it is longer. Third!';
const nonAsciiText = 'Café über naïve 😀 done.';
const cancelledText =
    'This stream stops at its first chunk. The second sentence never comes. '
    'Neither does the third. The fourth stays silent too. So does the fifth. '
    'The sixth has nothing to say. The seventh is the same. The eighth as well.';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  if (query['runtime'] case final String runtime) {
    MediaPipeWebRuntime.baseUrl = runtime;
  }
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Checking speech'))),
    ),
  );
  final report = <String, Object?>{};
  try {
    report['capabilities'] = {
      'transcriber': (await queryAudioTranscriberCapabilities()).isSupported,
      'speech': (await queryTextToSpeechCapabilities()).isSupported,
    };
    report['transcriber'] = await _transcriber(
      query['parakeet'] ?? AudioModels.parakeetTdtV3.url,
    );
    final afterCpu = await _work();
    report['transcriber_gpu'] = await _transcriberGpu(
      query['parakeet'] ?? AudioModels.parakeetTdtV3.url,
    );
    final afterGpu = await _work();
    report['speech'] = await _speech(query['phonon'] ?? AudioModels.phonon.url);
    report['pinned'] = await _pinned();
    report['work'] = {
      'after_cpu': afterCpu,
      'after_gpu': afterGpu,
      'after_speech': await _work(),
    };
    report['status'] = 'passed';
  } catch (error, stack) {
    report
      ..['status'] = 'failed'
      ..['error'] = '$error\n$stack';
  }
  _report = report.jsify();
}

/// The chunks the worker sends during [run], once they have all arrived.
Future<int> _chunksDuring(Future<void> Function() run) async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final before = _workerChunks;
  await run();
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return _workerChunks - before;
}

Future<AudioData> _clip(String name) async =>
    decodeWav(await loadAssetBytes('assets/samples/$name'));

Future<Map<String, Object?>> _transcriber(String model) async {
  final clip = await _clip('speech_16000_hz_mono.wav');
  final report = <String, Object?>{};
  final task = await AudioTranscriber.create(
    AudioTranscriberOptions(modelPath: model),
  );
  try {
    await task.prewarm();
    final whole = await task.transcribe(clip);
    report['text'] = whole.text;
    report['whole'] = _segments(whole);
    // A stream of one-second blocks, each call's answer on its own.
    report['stream'] = [
      for (final block in _blocks(clip))
        _segments(await task.transcribe(block, endOfStream: false)),
      _segments(await task.finishStream()),
    ];
    try {
      await task.transcribe(
        AudioData(samples: clip.samples, sampleRate: 48000),
      );
      report['wrong_rate'] = 'accepted';
    } on ArgumentError catch (error) {
      report['wrong_rate'] = '${error.name}: ${error.message}';
    }
    // Past the model's 5 s window, whose streaming windows then finalize
    // segments before the end.
    report['long_whole'] = _segments(await task.transcribe(_joined(clip)));
  } finally {
    await task.dispose();
  }
  report['after_dispose'] = await _failure(() => task.transcribe(clip));

  final interim = await AudioTranscriber.create(
    AudioTranscriberOptions(modelPath: model, enableInterimResults: true),
  );
  try {
    report['interim'] = [
      for (final block in _blocks(clip))
        _segments(await interim.transcribe(block, endOfStream: false)),
      _segments(await interim.finishStream()),
    ];
    // The long input twice on the one task, which must answer the same.
    final long = _joined(clip);
    for (final name in ['long_interim', 'long_interim_again']) {
      report[name] = [
        for (final block in _blocks(long))
          _segments(await interim.transcribe(block, endOfStream: false)),
        _segments(await interim.finishStream()),
      ];
    }
  } finally {
    await interim.dispose();
  }

  // Google resamples another rate to the model's.
  final clip48 = await _clip('speech_48000_hz_mono.wav');
  final resampled = await AudioTranscriber.create(
    AudioTranscriberOptions(modelPath: model, sampleRateHz: 48000),
  );
  try {
    report['resampled'] = _segments(await resampled.transcribe(clip48));
  } finally {
    await resampled.dispose();
  }
  return report;
}

/// The GPU delegate where this browser is offered it, or the refusal where it
/// is not. The test counts the WebGPU work the worker submits, as a delegate
/// that stays on the CPU answers the same.
Future<Map<String, Object?>> _transcriberGpu(String model) async {
  final capabilities = await queryAudioTranscriberCapabilities();
  final options = AudioTranscriberOptions(
    modelPath: model,
    delegate: Delegate.gpu,
  );
  if (!capabilities.supportedDelegates.contains(Delegate.gpu)) {
    return {
      'offered': false,
      'adapter': capabilities.platform.gpu,
      'reason': capabilities.unavailableReasons[Delegate.gpu],
      'refused': await _failure(() => AudioTranscriber.create(options)),
    };
  }
  final clip = await _clip('speech_16000_hz_mono.wav');
  final task = await AudioTranscriber.create(options);
  try {
    final whole = await task.transcribe(clip);
    return {
      'offered': true,
      'adapter': capabilities.platform.gpu,
      'text': whole.text,
      'whole': _segments(whole),
    };
  } finally {
    await task.dispose();
  }
}

Iterable<AudioData> _blocks(AudioData clip) sync* {
  final size = clip.sampleRate.toInt();
  for (var start = 0; start < clip.samples.length; start += size) {
    final end = start + size;
    yield AudioData(
      samples: Float32List.sublistView(
        clip.samples,
        start,
        end < clip.samples.length ? end : clip.samples.length,
      ),
      sampleRate: clip.sampleRate,
    );
  }
}

/// [clip] three times, with a second of silence between two copies, as
/// packages/mediapipe-task-audio/tool/generate_speech_reference.py builds
/// its long cases.
AudioData _joined(AudioData clip) {
  final length = clip.samples.length;
  final gap = clip.sampleRate.toInt();
  final samples = Float32List(3 * length + 2 * gap);
  for (var copy = 0; copy < 3; copy++) {
    samples.setAll(copy * (length + gap), clip.samples);
  }
  return AudioData(samples: samples, sampleRate: clip.sampleRate);
}

List<Object?> _segments(AudioTranscriberResult result) => [
  for (final segment in result.segments)
    {
      'transcript': segment.transcript,
      'isFinal': segment.isFinal,
      'from': segment.fromTimestampMilliseconds,
      'to': segment.toTimestampMilliseconds,
    },
];

Future<Map<String, Object?>> _speech(String model) async {
  final report = <String, Object?>{};
  final task = await TextToSpeech.create(TextToSpeechOptions(modelPath: model));
  try {
    report['voices'] = [
      for (final voice in await task.listVoices())
        {
          'voiceId': voice.voiceId,
          'displayName': voice.displayName,
          'locale': voice.locale,
          'sampleRateHz': voice.sampleRateHz,
          'isDownloaded': voice.isDownloaded,
        },
    ];
    report['fox'] = _audio(await task.synthesize(foxText));
    report['french'] = _audio(
      await task.synthesize(frenchText, voiceId: 'claire', locale: 'fr-FR'),
    );
    report['non_ascii'] = _audio(await task.synthesize(nonAsciiText));
    report['stream'] = [
      await for (final chunk in task.synthesizeStream(streamText))
        _audio(chunk),
    ];
    // Leaving at the first chunk stops the worker's stream, and the task still
    // answers the next call as before. The chunks are counted where the worker
    // sends them, as the Dart side stops listening whether or not the worker
    // stops. The next call queues behind the stream, so the count is whole once
    // it answers.
    report['uncancelled_chunks'] = await _chunksDuring(
      () => task.synthesizeStream(cancelledText).drain<void>(),
    );
    var chunks = 0;
    report['cancelled_worker_chunks'] = await _chunksDuring(() async {
      await for (final _ in task.synthesizeStream(cancelledText)) {
        chunks++;
        break;
      }
      report['after_cancel'] = _audio(await task.synthesize(foxText));
    });
    report['cancelled_chunks'] = chunks;
    // In order, with a stream's chunks ahead of the call made after it.
    final order = <String>[];
    final stream = task.synthesizeStream(frenchText).forEach((_) {
      order.add('chunk');
    });
    final next = task.synthesize(foxText).then((_) => order.add('call'));
    await Future.wait([stream, next]);
    report['order'] = order;
    // The task's cancel fails the call it runs and the one queued behind it
    // as Google's native one does, ends a stream without an error, and
    // leaves the task answering; with nothing in flight it does nothing.
    final running = _failure(() => task.synthesize(cancelledText));
    final queued = _failure(() => task.synthesize(foxText));
    final cancelledStream = task.synthesizeStream(cancelledText).length;
    task.cancel();
    report['task_cancel'] = {
      'running': await running,
      'queued': await queued,
      'stream_chunks': await cancelledStream,
    };
    report['after_task_cancel'] = _audio(await task.synthesize(foxText));
    task.cancel();
    report['after_idle_cancel'] = _audio(await task.synthesize(foxText));
  } finally {
    await task.dispose();
  }
  report['after_dispose'] = await _failure(() => task.synthesize(foxText));
  report['cancel_after_dispose'] = await _failure(task.cancel);

  final faster = await TextToSpeech.create(
    TextToSpeechOptions(modelPath: model, speakingRate: 1.5),
  );
  try {
    report['faster'] = _audio(await faster.synthesize(foxText));
  } finally {
    await faster.dispose();
  }

  // Google's compile cache, in the runtime's own virtual file system.
  try {
    final cached = await TextToSpeech.create(
      TextToSpeechOptions(modelPath: model, cacheDirectory: '/speech-cache'),
    );
    try {
      report['cached'] = _audio(await cached.synthesize(foxText));
    } finally {
      await cached.dispose();
    }
  } catch (error) {
    report['cached'] = '$error';
  }

  try {
    await TextToSpeech.create(
      TextToSpeechOptions(modelPath: model, delegate: Delegate.gpu),
    );
    report['gpu'] = 'accepted';
  } on RuntimeUnavailableException {
    report['gpu'] = 'RuntimeUnavailableException';
  }
  return report;
}

/// The pinned model, as an app asks for it: downloaded once, verified against
/// its SHA-256, kept in Cache Storage and handed to the worker as bytes.
Future<Map<String, Object?>> _pinned() async {
  final store = ModelStore();
  await store.clear();
  final report = <String, Object?>{};
  report['without_download'] = await _failure(
    () => TextToSpeech.create(TextToSpeechOptions(model: AudioModels.phonon)),
  );
  ModelStore.allowDownloads = true;
  try {
    final task = await TextToSpeech.create(
      TextToSpeechOptions(model: AudioModels.phonon),
    );
    try {
      report['fox'] = _audio(await task.synthesize(foxText));
    } finally {
      await task.dispose();
    }
  } finally {
    ModelStore.allowDownloads = false;
    await store.clear();
  }
  return report;
}

/// The name of what [call] throws, or `accepted`; spelled out, as a release
/// build minifies `runtimeType`.
Future<String> _failure(FutureOr<Object?> Function() call) async {
  try {
    await call();
    return 'accepted';
  } on StateError {
    return 'StateError';
  } on RuntimeUnavailableException {
    return 'RuntimeUnavailableException';
  } catch (error) {
    return '$error';
  }
}

Map<String, Object?> _audio(TextToSpeechResult result) => {
  'sha256': sha256
      .convert(
        result.samples.buffer.asUint8List(
          result.samples.offsetInBytes,
          result.samples.lengthInBytes,
        ),
      )
      .toString(),
  'samples': result.samples.length,
  'sampleRateHz': result.sampleRateHz,
  'chunkIndex': result.chunkIndex,
  'isFinal': result.isFinal,
  'words': [
    for (final word in result.wordTimestamps)
      [word.word, word.start, word.end, word.startSeconds, word.endSeconds],
  ],
};

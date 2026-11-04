// The text and audio tasks through the public Dart API in a browser, for
// tool/browser/test_browser.mjs --suite=text-audio, which compares every
// number here with Google's JavaScript run on the same page, runtime and
// inputs; the audio stream, which browsers run emulated on Google's clips
// mode, included. With ?mic=1 it also streams two seconds of microphone
// input, which the test feeds from a speech clip through Chrome's fake
// capture.
// With ?runtime=<url> it loads Google's runtimes from there instead of
// jsDelivr, as an app self-hosting them does.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_gallery/audio/microphone.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';

@JS('mediapipeTextAudioReport')
external set _report(JSAny? value);

/// Texts and classifier options, shared with the JavaScript side of the test.
const classifierCases =
    <
      (String, ({int maxResults, double scoreThreshold, List<String> denylist}))
    >[
      (
        'Hello, world!',
        (maxResults: -1, scoreThreshold: 0.0, denylist: <String>[]),
      ),
      (
        'This was a terrible movie. I hated every minute.',
        (maxResults: -1, scoreThreshold: 0.0, denylist: <String>[]),
      ),
      (
        'Hello, world!',
        (maxResults: 1, scoreThreshold: 0.0, denylist: <String>[]),
      ),
      (
        'Hello, world!',
        (maxResults: -1, scoreThreshold: 0.0, denylist: ['positive']),
      ),
    ];
const embedderTexts = [
  'Hello, world!',
  'Hello there!',
  'The spacecraft landed on Mars.',
];
const languageTexts = [
  'Hello, world!',
  'Quiero agua, por favor.',
  'こんにちは、元気ですか？',
];

/// EmbeddingGemma inputs with Google's formatting modes, shared with the
/// JavaScript side of the test, which passes the same `TextFormatOptions`.
final embeddingGemmaCases = <(String, TextFormatContext?)>[
  ('A cat is sleeping on the sofa.', null),
  (
    'A cat is sleeping on the sofa.',
    TextFormatContext(taskType: EmbeddingType.semanticSimilarity),
  ),
  (
    'How do I grow tomatoes?',
    TextFormatContext(taskType: EmbeddingType.retrievalQuery),
  ),
  (
    'Plant tomatoes in a sunny spot and water regularly.',
    TextFormatContext(
      taskType: EmbeddingType.retrievalDocument,
      title: 'Growing tomatoes',
      role: TextRole.document,
    ),
  ),
  (
    'Sort a list of integers.',
    TextFormatContext(taskType: EmbeddingType.codeRetrieval),
  ),
];
const clips = ['speech_16000_hz_mono.wav', 'speech_48000_hz_mono.wav'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Uri.base.queryParameters['runtime'] case final String runtime) {
    MediaPipeWebRuntime.baseUrl = runtime;
  }
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Checking text and audio'))),
    ),
  );
  final report = <String, Object?>{};
  try {
    report['classifier'] = await _classifier();
    report['embedder'] = await _embedder();
    report['embedding_gemma'] = await _embeddingGemma();
    report['language'] = await _language();
    report['audio'] = await _audio();
    report['audio_stream'] = await _audioStream();
    report['model_cache'] = await _modelCache();
    if (Uri.base.queryParameters['mic'] == '1') {
      report['microphone'] = await _microphone();
    }
    report['status'] = 'passed';
  } catch (error, stack) {
    report
      ..['status'] = 'failed'
      ..['error'] = '$error\n$stack';
  }
  _report = report.jsify();
}

Future<String> _modelCache() async {
  final bytes = utf8.encode('verified web model');
  final digest = sha256.convert(bytes).toString();
  final store = ModelStore();
  await store.clear();
  final online = DownloadAsset(
    url: 'data:application/octet-stream;base64,${base64.encode(bytes)}',
    sha256: digest,
  );
  _require(
    (await store.get(online)).bytes.toString() == bytes.toString(),
    'The model store did not return verified bytes.',
  );
  final offline = DownloadAsset(
    url: 'https://invalid.example/model',
    sha256: digest,
  );
  _require(
    (await store.get(offline)).bytes.toString() == bytes.toString(),
    'The model store did not reuse its verified browser cache.',
  );
  await store.clear();
  return 'passed';
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> _rejects<T>(Future<Object?> Function() action) async {
  try {
    await action();
  } on Object catch (error) {
    _require(error is T, 'Expected $T, got $error');
    return;
  }
  throw StateError('Expected $T');
}

List<Object?> _categories(Iterable<Classifications> heads) => [
  for (final head in heads)
    [
      for (final c in head.categories)
        [c.index, c.score, c.categoryName, c.displayName],
    ],
];

Future<Object?> _classifier() async {
  final model = await loadAssetBytes(
    bundledModelFile('bert_classifier.tflite'),
  );
  final results = [];
  for (final (text, options) in classifierCases) {
    final task = await TextClassifier.create(
      TextClassifierOptions(
        modelBytes: model,
        maxResults: options.maxResults,
        scoreThreshold: options.scoreThreshold,
        categoryDenylist: options.denylist,
      ),
    );
    try {
      results.add(_categories((await task.classify(text)).classifications));
    } finally {
      await task.dispose();
    }
  }
  // A model given as a URL, then ordered requests and disposal.
  final byPath = await TextClassifier.create(
    TextClassifierOptions(
      modelPath: 'assets/${bundledModelFile('bert_classifier.tflite')}',
    ),
  );
  final queued = await Future.wait([
    for (final (text, _) in classifierCases.take(2)) byPath.classify(text),
  ]);
  _require(
    _categories(queued.first.classifications).toString() ==
        results.first.toString(),
    'A model from a URL must match the same model from bytes.',
  );
  await byPath.dispose();
  await byPath.dispose();
  await _rejects<StateError>(() => byPath.classify('Hello'));
  await _rejects<TaskException>(
    () => TextClassifier.create(
      TextClassifierOptions(modelBytes: Uint8List.fromList([1, 2, 3])),
    ),
  );
  return results;
}

Future<Object?> _embedder() async {
  final model = await loadAssetBytes(
    bundledModelFile('universal_sentence_encoder.tflite'),
  );
  final result = <String, Object?>{};
  for (final quantize in [false, true]) {
    final task = await TextEmbedder.create(
      TextEmbedderOptions(
        modelBytes: model,
        l2Normalize: quantize,
        quantize: quantize,
      ),
    );
    try {
      final embeddings = [
        for (final text in embedderTexts)
          (await task.embed(text)).embeddings.single,
      ];
      result[quantize ? 'quantized' : 'float'] = {
        'values': [
          for (final e in embeddings)
            quantize
                ? e.quantizedEmbedding!.toList()
                : e.floatEmbedding!.toList(),
        ],
        'head': [embeddings.first.headIndex, embeddings.first.headName],
        'similarity': [
          TextEmbedder.cosineSimilarity(embeddings[0], embeddings[1]),
          TextEmbedder.cosineSimilarity(embeddings[0], embeddings[2]),
        ],
      };
    } finally {
      await task.dispose();
    }
  }
  return result;
}

/// EmbeddingGemma through Google's browser TextEmbedder, when the build
/// bundles its 184 MB model (prepare_gallery.dart --tasks ...,embedding_gemma).
Future<Object?> _embeddingGemma() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('assets/manifest.json'))
          as Map<String, dynamic>;
  if (!(manifest['tasks'] as List).contains('embedding_gemma')) {
    return 'not bundled';
  }
  final support = await queryTextEmbedderCapabilities(
    TextModels.embeddingGemma,
  );
  _require(
    support.supportedDelegates.contains(Delegate.cpu),
    'EmbeddingGemma must be supported in browsers.',
  );
  final model = await loadAssetBytes(bundledModelFile('embedding_gemma.task'));
  final result = <String, Object?>{};
  for (final quantize in [false, true]) {
    final task = await TextEmbedder.create(
      TextEmbedderOptions(
        modelBytes: model,
        l2Normalize: quantize,
        quantize: quantize,
      ),
    );
    try {
      final embeddings = [
        for (final (text, context)
            in quantize ? embeddingGemmaCases.take(2) : embeddingGemmaCases)
          (await task.embed(text, formatContext: context)).embeddings.single,
      ];
      result[quantize ? 'quantized' : 'float'] = {
        'values': [
          for (final e in embeddings)
            quantize
                ? e.quantizedEmbedding!.toList()
                : e.floatEmbedding!.toList(),
        ],
        'head': [embeddings.first.headIndex, embeddings.first.headName],
        'similarity': quantize
            ? null
            : [
                TextEmbedder.cosineSimilarity(embeddings[0], embeddings[1]),
                TextEmbedder.cosineSimilarity(embeddings[2], embeddings[3]),
              ],
      };
    } finally {
      await task.dispose();
    }
  }
  return result;
}

Future<Object?> _language() async {
  final task = await LanguageDetector.create(
    LanguageDetectorOptions(
      modelBytes: await loadAssetBytes(
        bundledModelFile('language_detector.tflite'),
      ),
      maxResults: 3,
    ),
  );
  try {
    return [
      for (final text in languageTexts)
        [
          for (final p in (await task.detect(text)).predictions)
            [p.languageCode, p.probability],
        ],
    ];
  } finally {
    await task.dispose();
  }
}

List<Object?> _chunks(List<AudioClassifierResult> result) => [
  for (final chunk in result)
    [
      chunk.timestampMilliseconds,
      [
        for (final c in chunk.classifications.first.categories.take(5))
          [c.index, c.score, c.categoryName],
      ],
    ],
];

Future<Object?> _audio() async {
  final task = await AudioClassifier.create(
    AudioClassifierOptions(
      modelBytes: await loadAssetBytes(bundledModelFile('yamnet.tflite')),
    ),
  );
  final result = <String, Object?>{};
  try {
    for (final clip in clips) {
      result[clip] = _chunks(
        await task.classify(
          decodeWav(await loadAssetBytes('assets/samples/$clip')),
        ),
      );
    }
  } finally {
    await task.dispose();
  }
  await _rejects<StateError>(
    () => task.classify(
      AudioData(samples: Float32List(16000), sampleRate: 16000),
    ),
  );
  await _rejects<MediaPipeException>(
    () => AudioClassifier.create(
      AudioClassifierOptions(modelBytes: Uint8List.fromList([1, 2, 3])),
    ),
  );
  return result;
}

/// Speech through the Dart audio stream, which browsers run emulated on
/// Google's clips mode: in 100 ms blocks at the model's rate, in blocks of
/// 4801 at 48 kHz, and the lone half second; and the checks' messages, which
/// must be native platforms' to the letter.
Future<Object?> _audioStream() async {
  final model = await loadAssetBytes(bundledModelFile('yamnet.tflite'));
  final speech = decodeWav(
    await loadAssetBytes('assets/samples/speech_16000_hz_mono.wav'),
  );
  final result = <String, Object?>{
    'speech-100ms': await _streamed(model, speech, 1600),
    'speech-48k': await _streamed(
      model,
      decodeWav(
        await loadAssetBytes('assets/samples/speech_48000_hz_mono.wav'),
      ),
      4801,
    ),
    'lone-half-second': await _streamed(
      model,
      AudioData(
        samples: Float32List.sublistView(speech.samples, 0, 8000),
        sampleRate: 16000,
      ),
      8000,
    ),
  };
  final task = await _streamTask(model);
  try {
    task.results.listen((_) {});
    task.classifyAsync(
      AudioData(samples: Float32List(1600), sampleRate: 16000),
      timestampMilliseconds: 10,
    );
    String? refusal(void Function() call) {
      try {
        call();
      } on ArgumentError catch (error) {
        return '${error.name}: ${error.message}';
      }
      return null;
    }

    result['rate'] = refusal(
      () => task.classifyAsync(
        AudioData(samples: Float32List(4800), sampleRate: 48000),
        timestampMilliseconds: 20,
      ),
    );
    result['timestamp'] = refusal(
      () => task.classifyAsync(
        AudioData(samples: Float32List(1600), sampleRate: 16000),
        timestampMilliseconds: 10,
      ),
    );
    // A mono model takes any channel count.
    result['stereo'] =
        refusal(
          () => task.classifyAsync(
            AudioData(
              samples: Float32List(3200),
              sampleRate: 16000,
              channels: 2,
            ),
            timestampMilliseconds: 110,
          ),
        ) ??
        'accepted';
  } finally {
    await task.dispose();
  }
  return result;
}

Future<AudioClassifier> _streamTask(Uint8List model) => AudioClassifier.create(
  AudioClassifierOptions(
    modelBytes: model,
    runningMode: AudioRunningMode.audioStream,
  ),
);

/// [audio] in blocks of [blockFrames], each stamped with its first frame's
/// time; the results that arrived before `dispose()` and all of them.
Future<Object?> _streamed(
  Uint8List model,
  AudioData audio,
  int blockFrames,
) async {
  final task = await _streamTask(model);
  final results = <AudioClassifierResult>[];
  final done = Completer<void>();
  task.results.listen(
    results.add,
    onError: (Object error) => done.completeError(error),
    onDone: done.complete,
  );
  final rate = audio.sampleRate.toInt();
  final frames = audio.samples.length;
  for (var start = 0; start < frames; start += blockFrames) {
    task.classifyAsync(
      AudioData(
        samples: Float32List.sublistView(
          audio.samples,
          start,
          start + blockFrames < frames ? start + blockFrames : frames,
        ),
        sampleRate: audio.sampleRate,
      ),
      timestampMilliseconds: start * 1000 ~/ rate,
    );
  }
  // Every full window arrives before the close, so what arrives during it is
  // what the close flushed.
  final full = frames * 16000 ~/ rate ~/ 15600;
  for (var i = 0; i < 600 && results.length < full; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  final before = results.length;
  await task.dispose();
  await done.future;
  return {'before_dispose': before, 'chunks': _chunks(results)};
}

/// Two seconds of microphone input at 16 kHz, streamed as the gallery's
/// microphone mode streams it: the recorder's chunks become blocks stamped
/// from the samples sent.
Future<Object?> _microphone() async {
  const rate = 16000;
  final task = await _streamTask(
    await loadAssetBytes(bundledModelFile('yamnet.tflite')),
  );
  final results = <AudioClassifierResult>[];
  final done = Completer<void>();
  task.results.listen(
    results.add,
    onError: (Object error) => done.completeError(error),
    onDone: done.complete,
  );
  final blocks = PcmBlocks(rate);
  var samples = 0;
  final heard = Completer<void>();
  final audio = await recorderMicrophone(rate);
  final subscription = audio.listen((chunk) {
    if (blocks.add(chunk) case (final block, final timestamp)) {
      task.classifyAsync(block, timestampMilliseconds: timestamp);
      samples += block.samples.length;
      if (samples >= rate * 2 && !heard.isCompleted) heard.complete();
    }
  });
  try {
    await heard.future.timeout(const Duration(seconds: 20));
  } finally {
    await subscription.cancel();
  }
  await task.dispose();
  await done.future;
  return {'samples': samples, 'chunks': _chunks(results)};
}

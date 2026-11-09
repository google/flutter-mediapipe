/// Google's Audio Transcriber and Text to Speech on its browser runtime, each
/// on a worker of its own (assets/worker.js), through core's shared bridge.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/web_task_bridge.dart';

import 'speech_runners.dart';
import 'speech_types.dart';
import 'utf16_indices.dart';

/// Opens Google's Audio Transcriber on a worker.
Future<AudioTranscriberRunner> openWebAudioTranscriber(
  AudioTranscriberOptions options,
) async => _WebTranscriber(
  await _worker('AudioTranscriber', options, {
    'sampleRateHz': options.sampleRateHz,
    'enableInterimResults': options.enableInterimResults,
    'modelArchitecture': options.modelArchitecture.name.toUpperCase(),
    'prompt': _optional(options.prompt),
    'cacheDir': _optional(options.cacheDirectory),
  }),
);

/// Opens Google's Text to Speech on a worker.
Future<TextToSpeechRunner> openWebTextToSpeech(
  TextToSpeechOptions options,
) async => _WebTextToSpeech(
  await _worker('TextToSpeech', options, {
    'defaultVoiceId': _optional(options.defaultVoiceId),
    'defaultLocale': _optional(options.defaultLocale),
    'speakingRate': options.speakingRate,
    'targetBucket': options.targetBucket,
    'cacheDirectory': _optional(options.cacheDirectory),
  }),
);

/// Always names the delegate: Google's browser transcriber defaults to the
/// GPU and its Text to Speech to the CPU.
Future<WebTaskWorker> _worker(
  String task,
  TaskOptions options,
  Map<String, Object?> settings,
) => WebTaskWorker.create('mediapipe_audio', {
  ...settings,
  'task': task,
  'delegate': options.delegate == Delegate.gpu ? 'GPU' : 'CPU',
  'modelBytes': options.modelBytes,
  'modelPath': options.modelPath,
}, longRequests: true);

/// [value], or null when it is null or empty, as Google's Python passes
/// optional strings.
String? _optional(String? value) =>
    value == null || value.isEmpty ? null : value;

final class _WebTranscriber implements AudioTranscriberRunner {
  _WebTranscriber(this._worker);

  final WebTaskWorker _worker;

  @override
  Future<AudioTranscriberResult> transcribe(
    Float32List samples,
    bool endOfStream,
  ) => _segments(
    JSObject()
      ..['op'] = 'transcribe'.toJS
      // A copy, since the bridge transfers it to the worker.
      ..['samples'] = Float32List.fromList(samples).toJS
      ..['endOfStream'] = endOfStream.toJS,
  );

  @override
  Future<AudioTranscriberResult> finishStream() =>
      _segments(JSObject()..['op'] = 'finishStream'.toJS);

  @override
  Future<void> prewarm() =>
      _worker.runObject(JSObject()..['op'] = 'prewarm'.toJS);

  @override
  Future<void> dispose() => _worker.close();

  Future<AudioTranscriberResult> _segments(JSObject input) async {
    final segments = jsonDecode(await _worker.run(input)) as List<Object?>;
    return AudioTranscriberResult([
      for (final segment in segments.cast<Map<String, Object?>>())
        TranscriptionSegment(
          transcript: segment['transcript']! as String,
          isFinal: segment['isFinal']! as bool,
          fromTimestampMilliseconds: (segment['fromTimestampMs']! as num)
              .toInt(),
          toTimestampMilliseconds: (segment['toTimestampMs']! as num).toInt(),
        ),
    ]);
  }
}

final class _WebTextToSpeech implements TextToSpeechRunner {
  _WebTextToSpeech(this._worker);

  final WebTaskWorker _worker;

  /// How many times [cancel] was called, so a synthesis sent before a cancel
  /// fails even when the worker reads the cancel only after it: Google's
  /// JavaScript synthesize runs to its end without yielding to the worker's
  /// messages, so the call it runs and the one queued behind it both finish.
  var _cancels = 0;

  @override
  Future<List<TextToSpeechVoice>> listVoices() async {
    final voices =
        jsonDecode(await _worker.run(JSObject()..['op'] = 'listVoices'.toJS))
            as List<Object?>;
    return [
      for (final voice in voices.cast<Map<String, Object?>>())
        TextToSpeechVoice(
          voiceId: voice['voiceId']! as String,
          displayName: voice['displayName']! as String,
          locale: voice['locale']! as String,
          sampleRateHz: (voice['sampleRateHz']! as num).toInt(),
          isDownloaded: voice['isDownloaded']! as bool,
        ),
    ];
  }

  /// A cancelled synthesis answers `{cancelled: true}`, and fails as
  /// Google's native one does; so does one Google finished after a cancel,
  /// whose result is discarded, as natively.
  @override
  Future<TextToSpeechResult> synthesize(
    String text,
    String? voiceId,
    String? locale,
  ) async {
    final cancels = _cancels;
    final reply = (await _worker.runObject(
      _input('synthesize', text, voiceId, locale),
    ))!;
    if (reply.has('cancelled') || _cancels != cancels) {
      throw const TaskException('Synthesis cancelled.', statusCode: 1);
    }
    return _audio(reply, utf16Indices(text));
  }

  @override
  Stream<TextToSpeechResult> synthesizeStream(
    String text,
    String? voiceId,
    String? locale,
  ) {
    final indices = utf16Indices(text);
    return _worker
        .stream(_input('synthesizeStream', text, voiceId, locale))
        .map((chunk) => _audio(chunk, indices));
  }

  /// The worker reads a cancel only when it yields: between a stream's
  /// chunks, but not during Google's synthesize, which runs to its end.
  /// There it cancels Google's stream, and a request still queued is marked
  /// and stops before it starts. A synthesis the worker ran to its end
  /// before reading the cancel fails here, by [_cancels].
  @override
  void cancel() {
    _cancels++;
    _worker.cancelAll();
  }

  @override
  Future<void> dispose() => _worker.close();

  JSObject _input(String op, String text, String? voiceId, String? locale) =>
      JSObject()
        ..['op'] = op.toJS
        ..['text'] = text.toJS
        ..['voiceId'] = _optional(voiceId)?.toJS
        ..['locale'] = _optional(locale)?.toJS;

  TextToSpeechResult _audio(JSObject reply, Int32List indices) {
    final result =
        jsonDecode(reply.getProperty<JSString>('json'.toJS).toDart)
            as Map<String, Object?>;
    final words = (result['wordTimestamps'] as List<Object?>?) ?? const [];
    return TextToSpeechResult(
      samples: reply.getProperty<JSFloat32Array>('samples'.toJS).toDart,
      sampleRateHz: (result['sampleRateHz']! as num).toInt(),
      chunkIndex: (result['chunkIndex'] as num?)?.toInt() ?? 0,
      isFinal: result['isFinal'] as bool? ?? true,
      wordTimestamps: [
        for (final word in words.cast<Map<String, Object?>>())
          WordTimestamp(
            word: word['word']! as String,
            start:
                indices[(word['startChar']! as num).toInt().clamp(
                  0,
                  indices.length - 1,
                )],
            end:
                indices[(word['endChar']! as num).toInt().clamp(
                  0,
                  indices.length - 1,
                )],
            startSeconds: (word['startSec']! as num).toDouble(),
            endSeconds: (word['endSec']! as num).toDouble(),
          ),
      ],
    );
  }
}

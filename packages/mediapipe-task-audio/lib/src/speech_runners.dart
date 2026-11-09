/// The speech tasks' requests on whichever runtime serves them: Google's
/// native library, each task on a worker isolate of its own, or Google's
/// browser runtime, each on a web worker of its own.
library;

import 'dart:typed_data';

import 'speech_types.dart';

/// Audio Transcriber's requests, run in call order.
abstract interface class AudioTranscriberRunner {
  /// Transcribes mono [samples] at the options' rate; [endOfStream] ends the
  /// utterance they belong to.
  Future<AudioTranscriberResult> transcribe(
    Float32List samples,
    bool endOfStream,
  );

  /// Flushes the buffered audio and ends the stream.
  Future<AudioTranscriberResult> finishStream();

  /// Runs Google's warm-up pass.
  Future<void> prewarm();

  /// Waits for accepted requests, then closes Google's task once.
  Future<void> dispose();
}

/// Text to Speech's requests, run in call order.
abstract interface class TextToSpeechRunner {
  /// The voices in the loaded model.
  Future<List<TextToSpeechVoice>> listVoices();

  /// [text] as one utterance.
  Future<TextToSpeechResult> synthesize(
    String text,
    String? voiceId,
    String? locale,
  );

  /// [text] chunk by chunk, each as its clause is synthesized. Cancelling
  /// the subscription cancels Google's stream at once, a read in progress
  /// included, and in browsers between chunks.
  Stream<TextToSpeechResult> synthesizeStream(
    String text,
    String? voiceId,
    String? locale,
  );

  /// Cancels every accepted synthesis not yet finished; a no-op with none,
  /// and once disposed.
  void cancel();

  /// Waits for accepted requests, then closes Google's task once.
  Future<void> dispose();
}

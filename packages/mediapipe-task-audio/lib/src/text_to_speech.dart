import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import 'capabilities.dart';
import 'native_tasks.dart';
import 'speech_runners.dart';
import 'speech_types.dart';

/// Google's Text to Speech (for example Phonon): speech from text, as one
/// utterance or chunk by chunk, with when each word is spoken.
///
/// Google's native runtime serves it on 64-bit Android, iOS, macOS, Linux
/// and Windows, loading the model and synthesizing on a worker isolate, and
/// its browser runtime on a web worker.
///
/// ```dart
/// final task = await TextToSpeech.create(
///   TextToSpeechOptions(model: AudioModels.phonon),
/// );
/// final speech = await task.synthesize('Hello there.');
/// play(speech.samples, speech.sampleRateHz);
/// await task.dispose();
/// ```
///
/// Calls run one at a time, in call order; a stream holds the task until
/// it ends or its listener cancels. `cancel()` stops the work in flight.
/// `dispose()` waits for work already accepted and is idempotent.
final class TextToSpeech {
  TextToSpeech._(this._runner, this.delegate);

  final TextToSpeechRunner _runner;
  Future<void>? _disposing;

  /// The processor the task runs on, fixed at creation.
  final Delegate delegate;

  /// Resolves the model and opens Google's task; the model loads before
  /// this completes.
  static Future<TextToSpeech> create(TextToSpeechOptions options) async {
    requireDelegate(await queryTextToSpeechCapabilities(), options.delegate);
    await resolveTaskModel(options);
    try {
      return TextToSpeech._(
        await openNativeTextToSpeech(options),
        options.delegate,
      );
    } catch (error) {
      throw taskException(error);
    }
  }

  /// The voices in the loaded model.
  Future<List<TextToSpeechVoice>> listVoices() async {
    _check();
    return _runner.listVoices();
  }

  /// [text] spoken as one utterance, in [voiceId] and [locale], or the
  /// options' defaults where null.
  Future<TextToSpeechResult> synthesize(
    String text, {
    String? voiceId,
    String? locale,
  }) async {
    _check();
    return _runner.synthesize(text, voiceId, locale);
  }

  /// [text] spoken in short chunks, each as soon as it is synthesized (80
  /// to 320 ms of audio each with Phonon), so playback can start before
  /// the rest is ready. Word timestamps index into [text] and are timed
  /// from the stream's start.
  ///
  /// One subscription. Cancelling it cancels Google's stream at once, from
  /// the calling isolate, so a chunk in progress is abandoned; in a browser
  /// the cancel lands between chunks. A failure arrives as a
  /// [TaskException] and closes the stream.
  Stream<TextToSpeechResult> synthesizeStream(
    String text, {
    String? voiceId,
    String? locale,
  }) {
    _check();
    return _runner.synthesizeStream(text, voiceId, locale);
  }

  /// Cancels every synthesis accepted and not yet finished, running or
  /// waiting, unary or streamed, as Google's `TextToSpeech.cancel()` does.
  /// A cancelled [synthesize] fails with a [TaskException] whose
  /// `statusCode` is 1, Google's kMpCancelled, and a cancelled stream
  /// closes without an error. A call already finished keeps its result,
  /// and calls made afterwards run as usual. With nothing in flight, or
  /// after [dispose] completes, it does nothing.
  ///
  /// Google stops at its next check, within milliseconds of audio; it does
  /// not check while it analyses the text of a clause, which for one clause
  /// of about a thousand words takes over a second. In a browser, Google's
  /// synthesize does not let a cancel in until it ends, so a cancelled call
  /// still runs to its end before it fails; a stream stops between chunks.
  void cancel() => _runner.cancel();

  /// Finishes accepted work and releases Google's task. Repeated calls
  /// return the same completion; any other call afterwards fails with
  /// [StateError].
  Future<void> dispose() => _disposing ??= _runner.dispose();

  void _check() {
    if (_disposing != null) {
      throw StateError('TextToSpeech has been disposed.');
    }
  }
}

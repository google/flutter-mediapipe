# mediapipe_audio

Google's [MediaPipe] **Audio Classifier** for Dart and Flutter, for example
YAMNet's 521 sound categories, on Android, iOS, macOS, Linux, Windows and the
web. Google's pinned YAMNet model is bundled with your app at build time.

[MediaPipe]: https://developers.google.com/edge/mediapipe/solutions

Google's **Audio Transcriber** (speech to text, with Parakeet TDT 0.6B v3) and
**Text to Speech** (Phonon's five voices, whole or streamed, with word
timings) run on 64-bit Android, iOS, macOS, Linux, Windows and the web; see
[Speech](#speech).

## Platforms

The task runs Google's runtime on each platform, on the CPU: its MediaPipe
1.2.2 audio library on Android 9+, iOS 15+, macOS 14+ arm64, Linux x64 and
Windows x64, which this package's hook bundles, and
`@mediapipe/tasks-audio` 1.2.2 in browsers. The library is built for macOS 14
and tested on macOS 15.

No platform needs a setting. See
[platform setup](https://github.com/google/flutter-mediapipe/blob/main/doc/platform_setup.md)
for permissions, Linux graphics libraries and self-hosting the browser
runtime.

## Installation

Add the package from pub.dev, from your app's root:

```sh
flutter pub add mediapipe_audio
```

This adds `mediapipe_audio: ^0.2.1` to your app's `pubspec.yaml`. `mediapipe_core`
comes with it, and `mediapipe_audio.dart` exports its types, so you do not add or
import core yourself.

## Use

Bundle the model with your app: list it in the app's pubspec and declare the
folder it goes in.

```yaml
flutter:
  assets:
    - assets/mediapipe/

hooks:
  user_defines:
    mediapipe_audio:
      models: [yamnet]
```

Then run `dart run mediapipe_core:bundle_models` from the app's root, and
again whenever the list changes. It downloads the model once, checks it
against its pinned SHA-256 and writes it into `assets/mediapipe/`, so nothing
is downloaded at run time. `AudioModels.byName` lists the accepted names.

A model that is not bundled makes `create` throw a
`RuntimeUnavailableException` whose `fix` names the pubspec entry to add. To
download it at run time instead, set `ModelStore.allowDownloads = true` before
creating the task; Android release builds and sandboxed macOS apps then need
network permission, as
[platform setup](https://github.com/google/flutter-mediapipe/blob/main/doc/platform_setup.md)
describes.

<!-- sample: samples/audio/audio_classifier/clip.dart -->
```dart
import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

Future<void> classifyClip(Uint8List wavBytes) async {
  final classifier = await AudioClassifier.create(
    AudioClassifierOptions(model: AudioModels.yamnet, maxResults: 3),
  );
  try {
    final clip = decodeWav(wavBytes);
    for (final chunk in await classifier.classify(clip)) {
      final top = chunk.classifications.first.categories.first;
      print('${chunk.timestampMilliseconds} ms: ${top.categoryName}');
    }
  } finally {
    await classifier.dispose();
  }
}
```

The WAV bytes can come from an asset (`rootBundle.load`), a file picker or a
download, so the same code runs on every platform, browsers included.
`classify` returns one result per chunk the model reads (0.975 s for YAMNet),
each with its start time. It runs on a background isolate and serves calls in
order. `AudioData` takes interleaved samples in -1 to 1 at any sample rate and
channel count; Google's task resamples to the model's rate. `decodeWav` reads
16-bit PCM and 32-bit float WAV files. Each result lists the categories per
model head (`classifications`, on core's shared `Classifications`) and the
chunk's `timestampMilliseconds`. Options mirror Google's: `maxResults` (-1 for
all), `scoreThreshold`, `displayNamesLocale`, `categoryAllowlist` or
`categoryDenylist`, `delegate` (CPU) and `runningMode`
(`AudioRunningMode.audioClips`, or `audioStream` for live audio, below). To
use your own model, pass `modelPath` or `modelBytes` instead of `model`.

Query support before offering the task:

<!-- sample: samples/audio/audio_classifier/capabilities.dart -->
```dart
import 'package:mediapipe_audio/mediapipe_audio.dart';

Future<bool> audioAvailable() async {
  final support = await queryAudioClassifierCapabilities();
  return support.supportedDelegates.contains(Delegate.cpu);
}
```

Failures are `MediaPipeException`s: `RuntimeUnavailableException` (with a
`fix`), `ModelDownloadException`, and `TaskException` for errors from
Google's runtime. `dispose()` drains queued calls and is idempotent.

## Live audio

For audio that keeps coming, such as a microphone's, create the classifier in
`AudioRunningMode.audioStream` mode, listen to `results`, and hand each block
to `classifyAsync` as it arrives. Google frames the blocks into the model's
windows as one continuous signal, so a window may span several blocks and a
block may complete several windows.

<!-- sample: samples/audio/audio_classifier/stream.dart -->
```dart
import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Prints the top sound of each window of [blocks], 16 kHz mono audio.
Future<void> listen(Stream<Float32List> blocks) async {
  final classifier = await AudioClassifier.create(
    AudioClassifierOptions(
      model: AudioModels.yamnet,
      maxResults: 1,
      runningMode: AudioRunningMode.audioStream,
    ),
  );
  classifier.results.listen((window) {
    final top = window.classifications.first.categories.first;
    print('${window.timestampMilliseconds} ms: ${top.categoryName}');
  });
  var samples = 0;
  try {
    await for (final block in blocks) {
      classifier.classifyAsync(
        AudioData(samples: block, sampleRate: 16000),
        // Where the block starts, counted from the samples before it.
        timestampMilliseconds: samples * 1000 ~/ 16000,
      );
      samples += block.length;
    }
  } finally {
    // Classifies the audio short of a window, then closes `results`.
    await classifier.dispose();
  }
}
```

- **One result per window**, stamped with where its audio starts: the first
  block's timestamp plus the windows before it (975 ms each for YAMNet),
  whatever later blocks are stamped. `classifyAsync` returns at once.
- **Checked before Google's runtime**, with the same message on every
  platform: the first block fixes the sample rate; a mono model, such as
  YAMNet, takes any channel count, while any other model requires its own;
  timestamps are whole milliseconds, nonnegative, strictly increasing and at
  most 9007199254740, so a block shorter than a millisecond should wait for
  the next. A block refused for its rate or channels does not use up its
  timestamp.
- **Stamp blocks from the samples sent**, as above. Google's runtime logs a
  warning, every twentieth time, when a block's timestamp disagrees with the
  samples it has received, which a wall clock usually does; the warning is
  harmless.
- **`results` takes one listener, before the first block.** Pausing buffers,
  and cancelling discards later results while the stream goes on. A failure
  arrives on `results` as a `TaskException`, closes it, and every later
  `classifyAsync` throws it.
- **`dispose()` flushes the tail** as Google's close does: the audio short of
  a window is classified, delivered with the time it starts, and then
  `results` closes. A stream that ends on a window has no tail.
- **Nothing is dropped.** Every block is classified, in order. Blocks that
  arrive faster than the model runs, such as a file fed at once, wait in
  memory (64 KB per second of 16 kHz mono audio), and so do results while a
  listener is paused (about 50 KB a window with every category, little with a
  small `maxResults`).
- **Google's own stream** runs on Android, iOS, macOS, Linux and Windows,
  where at most 64 streams can be open at once in one app, since Google's C
  callback does not say which stream it serves and the package compiles one
  callback per stream; creating another throws a `TaskException`. Browsers
  have no such limit. Google's browser runtime has no stream, so in browsers the package frames the blocks itself
  and classifies each window with Google's clips mode. At the model's rate
  that gives exactly Google's results. At any other rate each window is
  resampled on its own, unlike Google's streaming resampler, so some windows
  can differ from Google's stream by steps of 1/256 of a score, as Google's
  own clips mode does: none on the 48 kHz speech sample, at most one step on
  speech at 44.1, 22.05 or 8 kHz, and up to 22 steps on a noisy synthetic
  signal. Record at the model's rate (16 kHz for YAMNet) to avoid the
  difference.

## Speech

`AudioTranscriber` turns speech into text and `TextToSpeech` turns text into
speech, on Google's 1.2.2 native library and, in browsers, on its 1.2.2
JavaScript runtime in a web worker. 32-bit Android cannot hold their models:
there `create` throws a `RuntimeUnavailableException`, and
`queryAudioTranscriberCapabilities()` and `queryTextToSpeechCapabilities()` say
why.

Both run on the CPU. Google's library can accept the GPU delegate and stay on
the CPU with the same answer, so this package offers it only where a test saw
the GPU do the work. That is `AudioTranscriber` on:

- macOS arm64 (Metal). CI's package and gallery tests check it on macOS 15,
  the only version CI runs. It passed once on macOS 14 before GitHub retired
  those runners, and no test runs on macOS 14 now.
- Chromium on a Mac's Apple adapter (WebGPU), which CI's browser job checks
  on macOS 15, and WebKit on that adapter, checked only on a developer's Mac.
  CI has no WebKit job on a Mac.
- iPhones and iPads (Metal), for an app that asks for `Delegate.gpu`; the CPU
  stays the default. It was tested on one iPhone 15 Pro (iOS 27): the same
  transcript as the CPU, about 1.7x faster per clip, but it holds about
  578 MB of GPU memory and takes about 4.6 s to create (0.6 s on the CPU).
  iPads and older iPhones were not tested, so test on your target devices.
  CI has no iPhone.

`TextToSpeech` is offered the GPU only on macOS 15 and later on arm64 (Metal) for
Kokoro (`AudioModels.kokoro`, 295 MB, Apache 2.0). CI's package tests check it
on macOS 15: Kokoro holds memory on Metal, and its speech is as long as on the
CPU, with each 100 ms window at nearly the same level. Kokoro has never run on
macOS 14, so there it gets the CPU, and a reason. Google runs only Kokoro's
vocoder on the GPU; its acoustic model, Phonon and PocketTTS run on the CPU. So
`create` takes the GPU delegate only for a model whose bundle marks a section
for the GPU, and throws a `RuntimeUnavailableException` for any other, such as
Phonon. A Kokoro file from elsewhere keeps Google's filename, which the task
reads to tell the models apart.

`AudioModels.kokoro` is `kokoro_int8_gpu_fp16.litertlm`, the file Google's
guide uses with the GPU delegate. Its model card warns that on the CPU
delegate, or with no GPU accelerator, its vocoder runs on the CPU and the
speech, though intelligible, may be noisier, and names
`kokoro_int8_fp16.litertlm` (the same voices, with more memory) for CPU-only
devices. This package offers Kokoro the GPU delegate only on macOS 15 and
later on arm64, so elsewhere it runs on the CPU. That file is not pinned: a
`modelPath` to a copy of it loads it.

Elsewhere, including Android, Linux, Windows, the iOS simulator, Firefox,
browsers on other adapters and browsers on iPhones and iPads, the GPU delegate
throws a `RuntimeUnavailableException` that says why. Firefox had no adapter where it
was tried, so it has no proof either way.

Their models are large (Parakeet
615 MB, CC BY 4.0; Phonon 87 MB; Kokoro 295 MB), so an app usually downloads
them on first use (`ModelStore.allowDownloads = true`) rather than bundling
them; listing `parakeet_tdt_v3`, `phonon` or `kokoro` under the hook's `models`
bundles them instead.

`AudioModels.pocketTtsEn` is Kyutai's PocketTTS English (163 MB, CC BY 4.0,
so an app that ships it credits Kyutai), as Google's LiteRT community
converted it. It speaks US English at 24 kHz in `alba` by default, with word
timestamps, on the CPU only. The speech tests compare its voices, two voices'
utterances, a faster rate and a streamed paragraph with Google's Python
(`test/fixtures/official_pocket_tts_reference.json`, from the macOS 1.2.2 wheel
and regenerated on each desktop CI runner), within Phonon's tolerances.
Browsers are not tested with it. Google's page says it has only the eight
`en-US` voices, but Google's 1.2.2 runtime also lists the multilingual bundle's
six others (`estelle`, `juergen`, `lola`, `rafael`, `giovanni`, `daan`) for
it, and speaks something for them, so choose an `en-US` one. Listing
`pocket_tts_en` under the hook's `models` bundles it.

In a browser, a pinned `model:` is verified and kept in Cache Storage, then
passes through the page's memory as bytes. For Parakeet, a `modelPath` URL
avoids that copy: Google's runtime reads the file itself, so the URL's server
must allow the page's origin. CI's browser job runs both models on the CPU in
Chromium, Firefox and WebKit on Linux and in Chromium on macOS 15, where
Parakeet also runs on the GPU (WebGPU); every browser job checks that Phonon
refuses the GPU delegate. On a developer's 48 GB Mac they also ran in Firefox
and WebKit. Phones' browsers are untested, and may not have the
memory for Parakeet.

<!-- sample: samples/audio/audio_transcriber/clip.dart -->
```dart
import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

Future<String> transcribeClip(Uint8List wavBytes) async {
  final clip = decodeWav(wavBytes);
  final transcriber = await AudioTranscriber.create(
    AudioTranscriberOptions(
      model: AudioModels.parakeetTdtV3,
      sampleRateHz: clip.sampleRate.round(),
    ),
  );
  try {
    return (await transcriber.transcribe(clip)).text;
  } finally {
    await transcriber.dispose();
  }
}
```

To transcribe live audio, such as a microphone's, pass each block to
`transcribe` with `endOfStream: false`. Google keeps what is short of a
segment for the next call, so a call can return no segment at all.
`finishStream()` transcribes what is left and ends the stream; the same task
can then start another. With `enableInterimResults: true`, a call also
returns the segment in progress, marked `isFinal: false` and restated from
the segment's start each time, which later audio may revise. The blocks
below are 16 kHz, the options' default `sampleRateHz`.

<!-- sample: samples/audio/audio_transcriber/stream.dart -->
```dart
import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Prints what Parakeet hears in [blocks], 16 kHz mono audio, as it hears it.
Future<void> transcribeLive(Stream<Float32List> blocks) async {
  final transcriber = await AudioTranscriber.create(
    AudioTranscriberOptions(
      model: AudioModels.parakeetTdtV3,
      enableInterimResults: true,
    ),
  );
  void show(AudioTranscriberResult result) {
    for (final segment in result.segments) {
      print(
        '${segment.fromTimestampMilliseconds}-'
        '${segment.toTimestampMilliseconds} ms '
        '${segment.isFinal ? 'final' : 'interim'}: ${segment.transcript}',
      );
    }
  }

  try {
    await for (final block in blocks) {
      final audio = AudioData(samples: block, sampleRate: 16000);
      show(await transcriber.transcribe(audio, endOfStream: false));
    }
    show(await transcriber.finishStream());
  } finally {
    await transcriber.dispose();
  }
}
```

`prewarm()` runs Google's warm-up pass, so the first `transcribe` is not
slower than the rest. Call it before the first clip arrives, while the app
has time to spare.

<!-- sample: samples/audio/audio_transcriber/prewarm.dart -->
```dart
import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Prints Parakeet's transcript of each of [clips], which share one rate,
/// warming the task up first.
Future<void> transcribeAll(List<AudioData> clips) async {
  final transcriber = await AudioTranscriber.create(
    AudioTranscriberOptions(
      model: AudioModels.parakeetTdtV3,
      sampleRateHz: clips.first.sampleRate.round(),
    ),
  );
  try {
    await transcriber.prewarm();
    for (final clip in clips) {
      print((await transcriber.transcribe(clip)).text);
    }
  } finally {
    await transcriber.dispose();
  }
}
```

`modelArchitecture` picks the model family Google routes the model to:
`TranscriberModelArchitecture.auto`, the default, reads it from the model
file, and `omni` takes an omni model's audio path. `prompt` sets a decoding
prompt for generative models; null keeps the model's. `cacheDirectory` names
a directory where Google's runtime caches compiled model artifacts between
runs; pass `':nocache'` to be sure caching is off.

To start playback before the whole text is synthesized, use
`synthesizeStream`. It yields the speech in short chunks as soon as each is
ready (80 to 320 ms of audio each with Phonon), each with its samples and the
timestamps of the words whose audio starts in it, often none. Cancelling the
subscription cancels Google's stream at once, abandoning the chunk in
progress.

<!-- sample: samples/audio/text_to_speech/stream.dart -->
```dart
import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Speaks [text] with Phonon, handing each chunk to [play] as soon as it is
/// ready. Completing [stop], from a Stop button for example, cancels the
/// rest.
Future<void> speakAsReady(
  String text, {
  required void Function(Float32List samples, int sampleRateHz) play,
  Future<void>? stop,
}) async {
  final tts = await TextToSpeech.create(
    TextToSpeechOptions(model: AudioModels.phonon),
  );
  final chunks = tts.synthesizeStream(text, voiceId: 'freya').listen((chunk) {
    // Chunk 0 can start playing while the rest is synthesized.
    play(chunk.samples, chunk.sampleRateHz);
    for (final word in chunk.wordTimestamps) {
      // Times count from the stream's start, not the chunk's.
      final spoken = text.substring(word.start, word.end);
      final at = word.startSeconds.toStringAsFixed(2);
      print('chunk ${chunk.chunkIndex}: $spoken at $at s');
    }
  });
  try {
    await Future.any([
      chunks.asFuture<void>(),
      if (stop != null) stop.then((_) => chunks.cancel()),
    ]);
  } finally {
    await tts.dispose();
  }
}
```

- `listVoices()` names the model's voices: Phonon has `freya`, `claire`,
  `lukas`, `sofia` and `lucas`. Google's guide says Phonon speaks US English
  only, though Google's 1.2.2 runtime, and so `listVoices()`, labels `claire`
  fr-FR, `lukas` de-DE, `sofia` es-ES and `lucas` pt-BR. For other languages,
  use Kokoro (`AudioModels.kokoro`).
- `defaultLocale` is null by default: Google infers the locale from the voice,
  as on its Web, Android and iOS tasks (its Python defaults to en-US).
- `WordTimestamp.start` and `end` are UTF-16 indices into the text, so
  `text.substring(start, end)` is the word, as above; Google reports UTF-8
  byte offsets, which the package converts.
- `cancel()` cancels every synthesis accepted and not yet finished, like
  Google's `cancel`: a cancelled `synthesize` call fails with a
  `TaskException` of status 1 (`Synthesis cancelled.`), and a cancelled
  stream closes without an error after the chunks it already yielded. Calls
  made after it run as usual; with nothing in flight, or once disposed, it
  does nothing.
- `defaultVoiceId` is the voice a call without a `voiceId` speaks in; null
  is the model's default voice. A call's `voiceId` and `locale` override the
  options' `defaultVoiceId` and `defaultLocale` for that call.
- `speakingRate` sets the speed (1 is normal, 2 twice as fast, at most 4),
  and `targetBucket` Kokoro's sequence-length bucket (64, 128 or 256 tokens,
  or 0, the default, for the model's own capacity), which Phonon and
  PocketTTS ignore. `cacheDirectory` is where Google's runtime caches
  unpacked model files and compiled weights between runs.
- Calls on one task run one at a time, in call order, on a worker isolate.

The sample below picks a voice for a locale from `listVoices()` and stops
when `stop` completes, as a Stop button would, by calling `cancel()`.

<!-- sample: samples/audio/text_to_speech/utterance.dart -->
```dart
import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Speaks [text] in the first Phonon voice for [locale], or in freya when
/// none speaks it, and returns null if [stop] completes first.
Future<Float32List?> speakInLocale(
  String text,
  String locale, {
  Future<void>? stop,
}) async {
  final tts = await TextToSpeech.create(
    TextToSpeechOptions(model: AudioModels.phonon, defaultVoiceId: 'freya'),
  );
  stop?.then((_) => tts.cancel());
  try {
    final voices = await tts.listVoices();
    for (final voice in voices) {
      print('${voice.voiceId} (${voice.displayName}): ${voice.locale}');
    }
    final voice = voices.where((v) => v.locale == locale).firstOrNull;
    print('Speaking in ${voice?.voiceId ?? 'the default voice'}');
    final speech = await tts.synthesize(
      text,
      voiceId: voice?.voiceId,
      locale: voice?.locale,
    );
    return speech.samples;
  } on TaskException catch (error) {
    if (error.statusCode != 1) rethrow; // 1: Google's status for cancelled
    print('Stopped');
    return null;
  } finally {
    await tts.dispose();
  }
}
```

### Limitations

- The multilingual PocketTTS bundle (`pocket_tts_int8`, about 760 MB) isn't
  tested yet. It can be loaded with `modelPath`; nothing checks that it works.
- Sending text in pieces (Google's `pushText` and `finishInput`) isn't
  supported: each call sends its whole text.
- Google's `computeWordTimestamps`, which aligns words with audio you supply,
  isn't supported.
- The `TINY_GEMMA` model architecture is not yet available: Google's 1.2.2 C
  library has only `auto` and `omni`, so the package offers those two.
- Google cannot interrupt its text analysis of a clause, which comes before
  that clause's audio, so a cancel during one very long clause lands only
  when the analysis ends. In CI, for a clause of about 4,800 characters, a
  cancel sent a tenth of the way into the analysis took about 1.2 s to land
  on macOS and Linux, and 1.7 s on Windows. Outside such a clause, a cancel
  landed within 40 ms there.
- In browsers, Google's `synthesize` does not let a cancel in until it ends,
  so a cancelled `synthesize` call, like one queued right behind it, still
  runs to its end before it fails with status 1. A stream reads a cancel
  between its chunks, so it may send the chunk in progress first. CI tests
  this in Chromium, Firefox and WebKit.
- `transcribe` needs `AudioData.sampleRate` to equal the options'
  `sampleRateHz`, and throws an `ArgumentError` otherwise: create the task at
  the audio's rate, or resample the audio first.
- Phones' browsers are untested.
- The GPU delegate is offered only where listed above; everywhere else it
  isn't supported.
- A model path that is missing, a directory or not a model makes `create`
  throw a `TaskException` with Google's own status and message, which depend
  on the platform and the file name: for the transcriber's missing file, `5`
  (NOT_FOUND) on macOS and Linux and `2` on Windows. On Linux, Google's Text
  to Speech ends the process instead for a missing Phonon or PocketTTS file
  and for a directory with Phonon's file name, so on Linux the package checks
  first that a Text to Speech model path is a file, and throws `5` with its
  own message for every path that is not. That differs from Google's `2` for
  a directory with Kokoro's file name.

## Validation

The tests compare every chunk of three official MediaPipe sample clips (speech
at 16 kHz and 48 kHz, and a clip YAMNet hears as animal and bird sounds) with
Google's own Python output (`test/fixtures/official_reference.json`, from the
macOS 1.1.0 wheel): same categories and
timestamps, scores within 0.00001, including resampling from 48 kHz. On Linux
and Windows CI, `tool/prepare_audio_reference.py` regenerates that reference
with Google's pinned wheel on the same runner (`tool/test_text_audio.py` at the
repository root runs both packages this way). The tests also check queued
calls, the score threshold, error reporting, disposal and the C struct layouts
against Google's ctypes definitions. Browser CI compares the Dart API with
Google's JavaScript on the same page and streams microphone input.

In audio stream mode the tests feed those clips as blocks (100 ms blocks, odd
lengths from a later first timestamp, the whole clip at once, 48 kHz in blocks
of 4801, stereo, a stream that ends on a window, and a lone half second) and
compare every window with Google's own stream
(`test/fixtures/official_stream_reference.json`, from the macOS 1.1.0 wheel,
regenerated with the pinned wheel on Linux and Windows CI): same timestamps,
the flushed tail's included once restamped, same categories, and scores within
0.00001. At the model's rate the package's emulation, run over the native
clips mode, must equal the native stream to the bit, and does (0.0 over every
score of every window). Browser CI compares the emulated stream with Google's
JavaScript on the same page; the iOS simulator, the Android emulator and
Firebase Test Lab's phones run the stream on Google's mobile libraries against
the same device's clips results.

The speech tests compare both tasks with Google's own Python
(`test/fixtures/official_speech_reference.json`, from the macOS 1.2.2 wheel,
Google's first release with these tasks in Python; the package loads the same
release's audio library): the transcript and segment timestamps of
both speech clips, whole and in one-second blocks with and without interim
results, and of three copies of a clip with a second of silence between them,
past the transcriber's 5 s window, twice on one task; and for Text to Speech
the voices, four utterances (Unicode text included, and French and German
text in the voices Google's runtime labels fr-FR and de-DE), a faster speaking
rate and a streamed
paragraph, each with the same sample count, rate and word timings, and the
peak and 100 ms RMS envelope within 0.002. On the Mac, where the Kokoro model
is downloaded, they compare Kokoro on the CPU the same way with
`test/fixtures/official_kokoro_reference.json`, made by
`tool/generate_speech_reference.py --kokoro-output` with the pinned 1.2.2
macOS arm64 wheel: Google's voice list, an English sentence in the default
voice and a French one in `ff_siwis`, and a task whose default voice is
`ff_siwis` speaking its own locale unless the options give another (Google
refuses `en-US` for it). `tool/prepare_speech_reference.py` regenerates the
references with the pinned wheel on each desktop CI runner (speech.yaml),
Kokoro's on the Mac alone. For a model path that is missing, a directory or a
file that is not a model, the tests expect Google's status and message from
`test/fixtures/official_speech_error_reference.json`, made by
`tool/generate_speech_error_reference.py` with the macOS arm64 wheel and
regenerated on each desktop runner with the references above, and by
`tool/test_text_audio.py`. On Linux, where Google ends the process for a
missing Phonon or PocketTTS file and a directory with Phonon's file name, they
expect the package's NOT_FOUND for every Text to Speech path that is not a
file, Kokoro's included (Google returns `5` for its missing file and `2` for
a directory with its name). They
also check stream cancellation, disposal, option checks, capabilities and the
C struct layouts against Google's headers.

# mediapipe_audio

Google's MediaPipe **Audio Classifier** for Dart and Flutter, for example
YAMNet's 521 sound categories, on Android, iOS, macOS, Linux, Windows and the
web. Google's pinned YAMNet model is bundled with your app at build time.

## Platforms

The task runs Google's runtime on each platform, on the CPU: its MediaPipe
1.2.0 audio library on Android 9+, iOS 15+, macOS 14+ arm64, Linux x64 and
Windows x64, which this package's hook bundles, and
`@mediapipe/tasks-audio` 1.2.0-rc.20261018 in browsers.

No platform needs a setting. See
[platform setup](https://github.com/google/flutter-mediapipe/blob/main/doc/platform_setup.md)
for permissions, Linux graphics libraries and self-hosting the browser
runtime.

## Use

Add `mediapipe_audio: ^0.1.0` to your app's dependencies. Bundle the model
with your app: list it in the app's pubspec and declare the folder it goes in.

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

# mediapipe_text

Google's MediaPipe text tasks for Dart and Flutter: text classification, text
embeddings (EmbeddingGemma included) and language detection on every
platform, plus Proofreader and Summarizer on every platform but the web.
Every task runs Google's official MediaPipe pipeline, and Google's pinned
models are bundled with your app at build time.

## Tasks and platforms

| Task | Class | Android | iOS | macOS arm64 | Linux x64 | Windows x64 | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Text classification (BERT) | `TextClassifier` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Text embeddings (Universal Sentence Encoder) | `TextEmbedder` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Language detection | `LanguageDetector` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| EmbeddingGemma 300M | `TextEmbedder` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Proofreader 200M | `TextProofreader` | ✓ | ✓ | ✓ | ✓ | ✓ | |
| Summarizer 200M | `TextSummarizer` | ✓ | ✓ | ✓ | ✓ | ✓ | |

All text tasks run on the CPU. The runtimes are Google's: its MediaPipe
1.2.0 text library on Android 9+, iOS 15+ (devices and the arm64 simulator),
macOS 14+, Linux and Windows, which this package's hook bundles, and
`@mediapipe/tasks-text` 1.2.0-rc.20261018 in browsers.

Google's browser runtime has no Proofreader or Summarizer
([UP-034](https://github.com/google/flutter-mediapipe/blob/main/upstream-issues.md#up-034-browser-text-runtime-omits-proofreader-and-summarizer)),
which their capability queries report there.

No platform needs a setting. See
[platform setup](https://github.com/google/flutter-mediapipe/blob/main/doc/platform_setup.md)
for permissions, Linux graphics libraries and self-hosting the browser
runtime.

## Quick start

Add `mediapipe_text: ^0.1.0` to your app's dependencies, then:

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> classify() async {
  final classifier = await TextClassifier.create(
    TextClassifierOptions(model: TextModels.bertClassifier),
  );
  try {
    final result = await classifier.classify('Hello, world!');
    final top = result.classifications.first.categories.first;
    print('${top.categoryName}: ${top.score}');
  } finally {
    await classifier.dispose();
  }
}
```

`TextModels` names Google's model for every task (`bertClassifier`,
`universalSentenceEncoder`, `languageDetector`, `embeddingGemma`,
`proofreader`, `summarizer`). Bundle the ones your app uses at build time:
list them in its pubspec, declare the folder they go in, and run
`dart run mediapipe_core:bundle_models` from the app's root, which downloads
each once and checks it against its SHA-256:

```yaml
flutter:
  assets:
    - assets/mediapipe/

hooks:
  user_defines:
    mediapipe_text:
      models: [bert_classifier]
```

`TextModels.byName` lists the accepted names. A model that is not bundled
makes `create` throw a `RuntimeUnavailableException` naming the entry to add;
setting `ModelStore.allowDownloads = true` from `mediapipe_core` downloads it
at run time instead. The text generation models are 118 to 184 MB, so weigh
that against your app's size. To use your own
model, pass `modelPath` (a file on native platforms, a URL in browsers) or
`modelBytes` (for example from `rootBundle`); the Proofreader and Summarizer
read their large models from a file, so they take `model` or `modelPath`.
Give exactly one model source.

Results own their data and stay valid after the task is disposed.

### Language detection

`LanguageDetector` returns language codes with probabilities, most likely
first.

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> detectLanguage(String text) async {
  final detector = await LanguageDetector.create(
    LanguageDetectorOptions(model: TextModels.languageDetector),
  );
  try {
    final result = await detector.detect(text);
    for (final prediction in result.predictions.take(3)) {
      print('${prediction.languageCode}: ${prediction.probability}');
    }
  } finally {
    await detector.dispose();
  }
}
```

### Text embeddings

`TextEmbedder` turns a sentence into a vector with the Universal Sentence
Encoder; the static `TextEmbedder.cosineSimilarity` compares two, including
quantized ones, computed in Dart so every platform gives the same answer. The
higher the value, the closer the meaning.

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<double> compareSentences(String first, String second) async {
  final embedder = await TextEmbedder.create(
    TextEmbedderOptions(model: TextModels.universalSentenceEncoder),
  );
  try {
    final a = await embedder.embed(first);
    final b = await embedder.embed(second);
    return TextEmbedder.cosineSimilarity(
      a.embeddings.first,
      b.embeddings.first,
    );
  } finally {
    await embedder.dispose();
  }
}
```

## Behavior

- `create` reports initialization errors and refuses a delegate the
  capability query rules out; each task runs on its own isolate and queues
  concurrent calls. Every task has a `delegate` getter.
- `dispose()` drains accepted calls, releases the native task and waits for
  the isolate to exit. It is idempotent; calls after it throw `StateError`.
- Failures are `MediaPipeException`s: `RuntimeUnavailableException` (the
  platform or settings cannot run the task, with a `fix`),
  `ModelDownloadException`, and `TaskException` with Google's message and
  native `statusCode`. Errors arrive through the returned `Future` or
  stream.
- Input containing NUL characters is rejected before it reaches native code.
- Nothing is reimplemented in Dart: tokenization, prompts, label order,
  thresholds, normalization and quantization are Google's.

Query support before offering a task or delegate:

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<bool> canSummarize() async {
  final support = await queryTextSummarizerCapabilities();
  return support.supportedDelegates.contains(Delegate.cpu);
}
```

The result also carries the reason for every unavailable delegate. It
describes declared support; it does not load a model.

## EmbeddingGemma 300M

`TextEmbedder` with `TextModels.embeddingGemma` runs Google's complete
EmbeddingGemma pipeline: prompt formatting, SentencePiece tokenization,
inference and postprocessing. It returns 768-value vectors on every platform,
with Google's prompt formatting on each runtime;
`queryTextEmbedderCapabilities(TextModels.embeddingGemma)` reports it.

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<double> similarity(String a, String b) async {
  final task = await TextEmbedder.create(
    TextEmbedderOptions(model: TextModels.embeddingGemma),
  );
  try {
    final context = TextFormatContext(
      taskType: EmbeddingType.semanticSimilarity,
    );
    final first = await task.embed(a, formatContext: context);
    final second = await task.embed(b, formatContext: context);
    return TextEmbedder.cosineSimilarity(
      first.embeddings.single,
      second.embeddings.single,
    );
  } finally {
    await task.dispose();
  }
}
```

All eight official formatting modes are supported, including retrieval
documents with titles and query/document roles; omitting `formatContext` passes
none to Google's API. `l2Normalize` and `quantize` (both off by default) go to
Google's postprocessor, and quantized results keep Google's signed-int8 bytes.
The model's 512-token limit includes formatting and special tokens; input is
never truncated or chunked. The model is 183.8 MB and under the
[Gemma Terms](https://ai.google.dev/gemma/terms).

## Proofreader 200M

`TextProofreader` runs Google's pipeline, including tokenization, generation
and the ordered corrections from Google's diff.

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> proofread() async {
  final task = await TextProofreader.create(
    TextProofreaderOptions(model: TextModels.proofreader),
  );
  try {
    final result = await task.proofread('She go home.');
    print(result.proofreadText);
    for (final edit in result.corrections) {
      print('${edit.type.name}: ${edit.text}');
    }
    await for (final update in task.proofreadStream('I recieved your mesage.')) {
      if (update.chunk != null) print(update.chunk);
      if (update.done) print(update.corrections);
    }
  } finally {
    await task.dispose();
  }
}
```

Chunks contain newly generated text; the final update carries the complete
corrections, each `same`, `insertion` or `deletion` in native order.

## Summarizer 200M

`TextSummarizer` runs Google's pipeline in either official mode,
`TextSummarizerMode.keypoints` (the default) or `.tldr`, fixed at creation.

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> summarize(String article) async {
  final task = await TextSummarizer.create(
    TextSummarizerOptions(
      model: TextModels.summarizer,
      mode: TextSummarizerMode.tldr,
    ),
  );
  try {
    print((await task.summarize(article)).summary);
    await for (final update in task.summarizeStream(article)) {
      if (update.chunk != null) print(update.chunk);
    }
  } finally {
    await task.dispose();
  }
}
```

Google's output is kept as is, bullet markers and whitespace included.

### Streaming, token budgets and cancellation

For Proofreader and Summarizer, streams start on listen and allow one
subscription; pausing buffers updates. Google's API has no cancellation, so
cancelling a stream stops delivery but waits for the native call to finish.
`maxNumTokens` and `cacheDirectory` go to Google's options (null or zero
selects the native default). Budgets include input and output, so an input
that already exceeds the budget returns a native error rather than being
truncated. Both models are 117.6 MB and under the
[Gemma Terms](https://ai.google.dev/gemma/terms).

## Validation

Every task is compared with Google's own output for the same model, runtime
version and inputs: 26 cases for the classic tasks, 17 for EmbeddingGemma, 9
for Proofreader and 10 for Summarizer. Generated text must match byte for
byte, and Google's releases generate different text, so each platform is
compared with Google's wheel of its own version: the checked-in macOS
references (Google's 1.1.0 wheel), references generated on the Linux and
Windows runners (`tool/test_modern_text.py`) and for the gallery's emulator
and simulator builds (`tool/prepare_modern_text_reference.py`), and Google's
JavaScript on the same page for EmbeddingGemma in browsers. Fresh Flutter apps built from the packages as pub.dev ships them run
the tasks in debug and release, alongside vision and audio. From the
repository root:

```sh
make get models
make test_text
```

`example/example.dart` classifies a sentence from the command line:
`dart run example/example.dart "What a great film"` in this package.

EmbeddingGemma, Proofreader and Summarizer are tagged `modern-text`: they need
the generative models (`make models` downloads them), and `dart test --tags
modern-text` runs them alone. The gallery's text pages demo them.

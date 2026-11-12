# mediapipe_text

Google's [MediaPipe] text tasks for Dart and Flutter: text classification, text
embeddings (EmbeddingGemma included) and language detection on every
platform, plus Proofreader and Summarizer on every platform except the web,
where they are not yet available.
Every task runs Google's official MediaPipe pipeline, and Google's pinned
models are bundled with your app at build time.

[MediaPipe]: https://developers.google.com/edge/mediapipe/solutions

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
1.2.3 text library on Android 9+, iOS 15+ (devices and the arm64 simulator),
macOS 14+, Linux and Windows, which this package's hook bundles, and
`@mediapipe/tasks-text` 1.2.3 in browsers.

Proofreader and Summarizer are not yet available on the web, matching the
MediaPipe Tasks Web SDK. Their capability queries report this in browsers.

No platform needs a setting. See
[platform setup](https://github.com/google/flutter-mediapipe/blob/main/doc/platform_setup.md)
for permissions, Linux graphics libraries and self-hosting the browser
runtime.

## Installation

Add the package from pub.dev, from your app's root:

```sh
flutter pub add mediapipe_text
```

This adds `mediapipe_text: ^0.2.1` to your app's `pubspec.yaml`. `mediapipe_core`
comes with it, and `mediapipe_text.dart` exports its types, so you do not add or
import core yourself.

## Quick start

<!-- sample: samples/text/text_classifier/classify.dart -->
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
setting `ModelStore.allowDownloads = true` downloads it at run time instead.
The text generation models are 118 to 184 MB, so weigh
that against your app's size. To use your own
model, pass `modelPath` (a file on native platforms, a URL in browsers) or
`modelBytes` (for example from `rootBundle`); the Proofreader and Summarizer
read their large models from a file, so they take `model` or `modelPath`.
Give exactly one model source.

Results own their data and stay valid after the task is disposed.

### Language detection

`LanguageDetector` returns language codes with probabilities, most likely
first.

<!-- sample: samples/text/language_detector/detect.dart -->
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

<!-- sample: samples/text/text_embedder/embed.dart -->
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

<!-- sample: samples/text/text_summarizer/capabilities.dart -->
```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<bool> canSummarize() async {
  final support = await queryTextSummarizerCapabilities();
  return support.supportedDelegates.contains(Delegate.cpu);
}
```

The result also carries the reason for every unavailable delegate. It
describes declared support; it does not load a model. Every task has a query,
and the Text Embedder's takes a model, because EmbeddingGemma needs 64-bit
Android where the classic embedders also run on 32-bit Android:

<!-- sample: samples/text/common/capabilities.dart -->
```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> reportTextSupport() async {
  final queries = <String, Future<TaskCapabilities> Function()>{
    'Text Classifier': queryTextClassifierCapabilities,
    'Language Detector': queryLanguageDetectorCapabilities,
    'Text Embedder': queryTextEmbedderCapabilities,
    'EmbeddingGemma': () =>
        queryTextEmbedderCapabilities(TextModels.embeddingGemma),
    'Proofreader': queryTextProofreaderCapabilities,
    'Summarizer': queryTextSummarizerCapabilities,
  };
  for (final MapEntry(key: task, value: query) in queries.entries) {
    final support = await query();
    final delegates = support.supportedDelegates.map((d) => d.name);
    print('$task: ${delegates.join(', ')}');
    for (final MapEntry(key: delegate, value: reason)
        in support.unavailableReasons.entries) {
      print('  no ${delegate.name}: $reason');
    }
  }
}
```

## EmbeddingGemma 300M

`TextEmbedder` with `TextModels.embeddingGemma` runs Google's complete
EmbeddingGemma pipeline: prompt formatting, SentencePiece tokenization,
inference and postprocessing. It returns 768-value vectors on every platform,
with Google's prompt formatting on each runtime;
`queryTextEmbedderCapabilities(TextModels.embeddingGemma)` reports it.

<!-- sample: samples/text/text_embedder/semantic_similarity.dart -->
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

All eight official formatting modes are supported; omitting `formatContext`
passes none to Google's API. `retrievalQuery` and `retrievalDocument` format a
search query and its documents. `questionAnswering`, `factChecking` and
`codeRetrieval` format either side of a pair, chosen by `role`
(`TextRole.query`, the default, or `TextRole.document`). A document can carry
a `title`:

<!-- sample: samples/text/text_embedder/question_answering.dart -->
```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> bestAnswer(String question, Map<String, String> answers) async {
  final task = await TextEmbedder.create(
    TextEmbedderOptions(model: TextModels.embeddingGemma),
  );
  try {
    final query = await task.embed(
      question,
      formatContext: TextFormatContext(
        taskType: EmbeddingType.questionAnswering,
      ),
    );
    for (final MapEntry(key: title, value: answer) in answers.entries) {
      final document = await task.embed(
        answer,
        formatContext: TextFormatContext(
          taskType: EmbeddingType.questionAnswering,
          role: TextRole.document,
          title: title,
        ),
      );
      final score = TextEmbedder.cosineSimilarity(
        query.embeddings.single,
        document.embeddings.single,
      );
      print('$title: ${score.toStringAsFixed(2)}');
    }
  } finally {
    await task.dispose();
  }
}
```
 `l2Normalize` and `quantize` (both off by default) go to
Google's postprocessor, and quantized results keep Google's signed-int8 bytes.
The model's 512-token limit includes formatting and special tokens; input is
never truncated or chunked. The model is 183.8 MB and under the
[Gemma Terms](https://ai.google.dev/gemma/terms).

## Proofreader 200M

`TextProofreader` runs Google's pipeline, including tokenization, generation
and the ordered corrections from Google's diff.

<!-- sample: samples/text/text_proofreader/proofread.dart -->
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
    await for (final update in task.proofreadStream(
      'I recieved your mesage.',
    )) {
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

<!-- sample: samples/text/text_summarizer/summarize.dart -->
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

Google's output is kept as is, bullet markers and whitespace included. In
keypoints mode the model writes each point on its own line, starting with
`* `:

<!-- sample: samples/text/text_summarizer/key_points.dart -->
```dart
import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> listKeyPoints(String article) async {
  final task = await TextSummarizer.create(
    TextSummarizerOptions(
      model: TextModels.summarizer,
      mode: TextSummarizerMode.keypoints,
    ),
  );
  try {
    final summary = (await task.summarize(article)).summary ?? '';
    for (final line in summary.split('\n')) {
      if (line.startsWith('* ')) print(line.substring(2));
    }
  } finally {
    await task.dispose();
  }
}
```

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
references (Google's 1.2.3 wheel for the classic tasks, its 1.1.0 wheel for
the others), references generated on the Linux and
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

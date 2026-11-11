# mediapipe_decision

Google's [MediaPipe] Decision Maker for Dart and Flutter. Ask a yes-or-no,
choice or score question about a piece of text and get Google's answer with
calibrated probabilities, in one forward pass of a small model rather than by
generating text. Every call runs Google's official MediaPipe pipeline.

[MediaPipe]: https://developers.google.com/edge/mediapipe/solutions

## Platforms

| Task | Class | Android | iOS | macOS arm64 | Linux x64 | Windows x64 | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Decision Maker | `DecisionMaker` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

The runtimes are Google's MediaPipe 1.2.2: its per-family decision C
library (its release build of November 2, 2026), which this package's build
hook downloads and checks against its SHA-256 on Android 9+, iOS 15+, macOS
14+, Linux and Windows, on the CPU; and `@mediapipe/tasks-decision`
1.2.2 in browsers, on the GPU delegate. Google's
browser runtime fails every evaluation on the CPU delegate and on browsers
without a hardware WebGPU adapter, so `queryDecisionMakerCapabilities()` offers
browsers only the GPU, and only on such an adapter; there it answers as the
desktop library does.

Google's browser runtime fails with some models:
`queryDecisionMakerCapabilities(model)` says where a model runs, and
`create` refuses one the runtime here cannot before downloading it. In
WebKit, the engine
of Safari and of every browser on iOS, it embeds every text as zeros with
both EmbeddingGemma 2 models, so every option scores the same; in every browser
it aborts while it creates the task with either GLiNER2.5-Decide model.
`queryDecisionMakerCapabilities(model)` reports both, and Laya runs in every
browser with a hardware WebGPU adapter. The browser runtime also ignores
`normalizePrior` and `scoringMode`.

## Installation

Add the package from pub.dev, from your app's root:

```sh
flutter pub add mediapipe_decision
```

This adds `mediapipe_decision: ^0.2.0` to your app's `pubspec.yaml`. `mediapipe_core`
comes with it, and `mediapipe_decision.dart` exports its types, so you do not add or
import core yourself.

## Quick start

<!-- sample: samples/decision/decision_maker/single.dart -->
```dart
import 'package:mediapipe_decision/mediapipe_decision.dart';

Future<void> decide() async {
  final capabilities = await queryDecisionMakerCapabilities();
  final task = await DecisionMaker.create(
    DecisionMakerOptions(
      model: DecisionModels.layaS256,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  try {
    const text = 'My order arrived broken and I want my money back.';
    final refund = await task.evaluateBoolean(
      text,
      BooleanQuestion('The customer wants a refund.'),
    );
    final topic = await task.evaluateChoice(
      text,
      ChoiceQuestion({
        'shipping': 'A problem with delivery or a damaged package',
        'billing': 'A question about a charge or a refund',
        'other': 'Anything else',
      }),
    );
    final mood = await task.evaluateScore(
      text,
      ScoreQuestion(['very unhappy', 'unhappy', 'neutral', 'happy']),
    );
    print('${refund.value} ${topic.selectedKey} ${mood.expectedScore}');
  } finally {
    await task.dispose();
  }
}
```

`DecisionModels` pins Google's decision models: Laya and GLiNER2.5-Decide
(`layaS256`, `layaS512`, `glinerS256`, `glinerS512`: 678 MB to 1.08 GB),
and EmbeddingGemma 2, which answers as fast at a fraction of the download:
`embeddingGemma2Text` (165 MB) and `embeddingGemma2TextVision` (388 MB),
which answer the same, everywhere but WebKit (see above). They are
large, so an app usually downloads one on first use rather than bundling
it: set
`ModelStore.allowDownloads = true` before `create`, or pass `modelPath`.
In browsers, `modelPath` can be the model's URL in Google's bucket, which
Google's runtime then fetches itself.

## Questions and answers

- `BooleanQuestion(condition, threshold:, temperature:, normalizePrior:)`
  answers with `BooleanResult(value, probabilityTrue, confidence)`.
- `ChoiceQuestion(criteria, instructions:, temperature:, scoringMode:,
  normalizePrior:)`, where `criteria` maps each option's key to a
  description, answers with `ChoiceResult(selectedKey, probabilities,
  confidence, predictionSet)`. The probabilities come in the question's
  order on every platform, and the prediction set is Google's Python rule:
  the most likely keys until 90% is covered.
- `ScoreQuestion(rubric, instructions:, temperature:)`, lowest level first,
  answers with `ScoreResult(expectedScore, probabilities, confidence,
  selectedKey)`.

`threshold` is the probability at which a boolean answer becomes true.
`instructions` gives the model a task prompt for a choice or a score, and
`temperature` replaces the model's calibrated softmax temperature.
`scoringMode` picks how the engine scores a choice's options: `auto` (the
engine's choice), `singleToken` (each option by its first token) or
`fullOption` (by all of its tokens). `normalizePrior` subtracts the model's
empty-context prior to remove label bias. Calls run one at a time, in call
order.

`DecisionMakerOptions.maxNumTokens` caps the input tokens Google's engine
reads. The default, 0, keeps the model's own budget (512 for EmbeddingGemma
2). The engine reserves memory for the whole budget when the task is
created, and cuts a longer input off without an error.

## Batches

To ask one question about many texts, use the batch forms
(`evaluateBooleanBatch`, `evaluateChoiceBatch` and `evaluateScoreBatch`):
one call returns a result per text, in the same order. `sharedPrefix` is
text that comes before every one of them, on a line of its own, such as a
header all the texts share; leave it out of the texts themselves.

<!-- sample: samples/decision/decision_maker/batch.dart -->
```dart
import 'package:mediapipe_decision/mediapipe_decision.dart';

Future<void> triage(List<String> messages) async {
  final capabilities = await queryDecisionMakerCapabilities();
  final task = await DecisionMaker.create(
    DecisionMakerOptions(
      model: DecisionModels.layaS256,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  try {
    const prefix = 'A message to our support team:';
    const rubric = ['very unhappy', 'unhappy', 'neutral', 'happy'];
    final refunds = await task.evaluateBooleanBatch(
      messages,
      BooleanQuestion('The customer wants a refund.'),
      sharedPrefix: prefix,
    );
    final topics = await task.evaluateChoiceBatch(
      messages,
      ChoiceQuestion(
        {
          'shipping': 'A problem with delivery or a damaged package',
          'billing': 'A question about a charge or a refund',
          'other': 'Anything else',
        },
        instructions: 'Choose the team that should answer the message.',
        scoringMode: ChoiceScoringMode.fullOption,
      ),
      sharedPrefix: prefix,
    );
    final moods = await task.evaluateScoreBatch(
      messages,
      ScoreQuestion(
        rubric,
        instructions: 'Rate how the customer feels.',
        temperature: 0.5,
      ),
      sharedPrefix: prefix,
    );
    for (var i = 0; i < messages.length; i++) {
      // A score's selectedKey is the index of its level, as text.
      final mood = rubric[int.parse(moods[i].selectedKey)];
      print(
        '"${messages[i]}" refund: ${refunds[i].value}, '
        'topic: ${topics[i].selectedKey}, mood: $mood',
      );
    }
  } finally {
    await task.dispose();
  }
}
```

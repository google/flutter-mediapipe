# MediaPipe Text for Flutter

![pub package](https://img.shields.io/pub/v/mediapipe_text)

A Flutter plugin to use the MediaPipe Text API, which contains multiple text-based Mediapipe tasks.

To learn more about MediaPipe, please visit the [MediaPipe website](https://developers.google.com/mediapipe)

## Getting Started

To get started with MediaPipe, please [see the documentation](https://developers.google.com/mediapipe/solutions/guide).

## Supported Tasks

<table>
    <tr>
        <th>Task</th>
        <th>Android</th>
        <th>iOS</th>
        <th>Web</th>
        <th>Windows</th>
        <th>macOS</th>
        <th>Linux</th>
    </tr>
    <tr>
        <td>Classification</td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
    </tr>
    <tr>
        <td>Embedding</td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
    </tr>
    <tr>
        <td>Language Detection</td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
    </tr>
</table>

## Usage

To get started with this plugin, you must be on the `master` channel.
Second, you will need to opt-in to the `native-assets` experiment,
using the `--enable-experiment=native-assets` flag whenever you run any commands
using the `$ dart` command line tool.

To enable this globally in Flutter, run:

```sh
$ flutter config --enable-native-assets
```

To disable this globally in Flutter, run:

```sh
$ flutter config --no-enable-native-assets
```

### Add dependencies

Add `mediapipe_text` and `mediapipe_core` to your `pubspec.yaml` file:

```
dependencies:
  flutter:
    sdk: flutter
  mediapipe_core: latest
  mediapipe_text: latest
```

### Add tflite models

Add the necessary models to your `assets` directory for each task you
intend to use:

```
flutter:
  assets:
    - assets/bert_classifier.tflite
    - assets/language_detector.tflite
    - assets/universal_sentence_encoder.tflite
```

These models can be downloaded at the following locations:

* [`bert_classifier.tflife`](https://storage.googleapis.com/mediapipe-models/text_classifier/bert_classifier/float32/latest/bert_classifier.tflite) (for Text Classification)
* [`language_detector.tflite`](language_detector/language_detector/float32/latest/language_detector.tflite) (for Language Detection)
* [`universal_sentence_encoder.tflife`](text_embedder/universal_sentence_encoder/float32/latest/universal_sentence_encoder.tflite) (for Text Embedding)

### Initialize your task worker

Text classification example:

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

// Load your text classifier tflite model into memory
ByteData? classifierBytes = await DefaultAssetBundle.of(context)
    .load('assets/bert_classifier.tflite');

// Create a `TextClassifier`
final classifier = TextClassifier(
  TextClassifierOptions.fromAssetBuffer(
    classifierBytes.buffer.asUint8List(),
  ),
);

// Classify some text!
final result = await classifier.classify('Hello, world!');
print(result.classifications.first);
```

Language detection example:

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

// Load your language detection tflite model into memory
ByteData? bytes = await DefaultAssetBundle.of(context)
    .load('assets/language_detector.tflite');

// Create a `LanguageDetector`
final detector = LanguageDetector(
  LanguageDetectorOptions.fromAssetBuffer(
    bytes.buffer.asUint8List(),
  ),
);

// Language-detect some text!
final result = await detector.detect('Hello, world!');
print(result.predictions.first);
```

Text embedding example:

```dart
import 'package:mediapipe_text/mediapipe_text.dart';

// Load your text embedding tflite model into memory
ByteData? embedderBytes = await DefaultAssetBundle.of(context)
    .load('assets/universal_sentence_encoder.tflite');

// Create a `TextEmbedder`
final embedder = TextEmbedder(
  TextEmbedderOptions.fromAssetBuffer(
    embedderBytes.buffer.asUint8List(),
  ),
);

// Embed some text!
final result = await embedder.embed('Hello, world!');
final result2 = await embedder.embed('Hello, moon!');

// Compare the results
final similarity = embedder.cosineSimilarity(
  result.embeddings.first,
  result2.embeddings.first,
);
```

## Running the example

To run the example project, download the models associated with whatever tasks
you want to explore, place them in the `packages/mediapipe_task_text/example/assets`
directory, and run the project on one of the supported platforms.

## Issues and feedback

Please file Flutter-MediaPipe specific issues, bugs, or feature requests in our [issue tracker](https://github.com/google/flutter-mediapipe/issues/new).

Issues that are specific to Flutter can be filed in the [Flutter issue tracker](https://github.com/flutter/flutter/issues/new).

To contribute a change to this plugin,
please review our [contribution guide](https://github.com/google/flutter-mediapipe/blob/master/CONTRIBUTING.md)
and open a [pull request](https://github.com/google/flutter-mediapipe/pulls).

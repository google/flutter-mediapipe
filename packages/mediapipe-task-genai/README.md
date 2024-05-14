# MediaPipe GenAI for Flutter

![pub package](https://img.shields.io/pub/v/mediapipe_genai)

A Flutter plugin to use the MediaPipe GenAI API, which contains multiple generative AI-based Mediapipe tasks.

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
        <td>Inference</td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/yes.png" /></td>
        <td align="center"><img height="16" width="16" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/no.png"/></td>
    </tr>
</table>

## Selecting a device

On-device inference is a demanding task, and as such is recommended to run on
Pixel 7 or newer (or other comprable Android devices) or iPhone 13's or newer
for iOS.

Mobile emulators are not supported.

For desktop, macOS is supported and Windows / Linux are coming soon.

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

Add `mediapipe_genai` and `mediapipe_core` to your `pubspec.yaml` file:

```
dependencies:
  flutter:
    sdk: flutter
  mediapipe_core: latest
  mediapipe_genai: latest
```

### Add tflite models

Unlike other MediaPipe task flavors (text, vision, and audio), generative AI
models must be downloaded at runtime from a URL hosted by the developer. To
acquire these models, you must create a [Kaggle](https://www.kaggle.com/) account,
accept the Terms of Service, download whichever models you want to use in your
app, self-host those models at a location of your choosing, and then configure
your app to download them at runtime.

See the example directory for a working implementation and directions on how
to get MediaPipe's inference task working.

### CPU vs GPU models

Inference tasks can either run on the CPU or GPU, and each model is compiled once
for each strategy. When you choose which model(s) to use from Kaggle, note their
CPU vs GPU variants and be sure to invoke the appropriate options constructor.

### Initialize your engine

Inference example:

```dart
import 'package:mediapipe_genai/mediapipe_genai.dart';

// Location where you downloaded the file at runtime, or
// placed the model yourself in advance (using `adb push`
// or similar)
final String modelPath = getModelPath();

// Select the CPU or GPU runtime, based on your model
// See the example for suitable values to pass to the rest
// of the `LlmInferenceOptions` class's parameters.
bool isGpu = yourValueHere;
final options = switch (isGpu) {
  true => LlmInferenceOptions.gpu(
    modelPath: modelPath,
    ...
  ),
  false => LlmInferenceOptions.cpu(
    modelPath: modelPath,
    ...
  ),
};

// Create an inference engine
final engine = LlmInferenceEngine(options);

// Stream results from the engine
final Stream<String> responseStream = engine.generateResponse('Hello, world!');
await for (final String responseChunk in responseStream) {
  print('the LLM said: $chunk');
}
```

## Issues and feedback

Please file Flutter-MediaPipe specific issues, bugs, or feature requests in our [issue tracker](https://github.com/google/flutter-mediapipe/issues/new).

Issues that are specific to Flutter can be filed in the [Flutter issue tracker](https://github.com/flutter/flutter/issues/new).

To contribute a change to this plugin,
please review our [contribution guide](https://github.com/google/flutter-mediapipe/blob/master/CONTRIBUTING.md)
and open a [pull request](https://github.com/google/flutter-mediapipe/pulls).

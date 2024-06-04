# MediaPipe GenAI example

A Flutter project demonstrating how to run MediaPipe's on-device inference task.

## Disclaimer

MediaPipe's inference APIs are new and experimental, and as such, this demo is prone
to occasional crashes. If the example app freezes up on you, kill it and restart.

## Running the sample

As described in `package:mediapipe_genai`'s own README, it is the developer's job
to self-host individual inference models and then download them onto a user's
device at runtime. To do this, your application code must know where to find said
models. For production applications, likely only one or two models will be
considered, so it is reasonable to supply two hard-coded download locations and
have the app acquire them at runtime.

However, this example is slightly different because it is a sandbox for experimentation.
As such, it directly supports using 4 different models:

* Gemma 4bit CPU
* Gemma 8bit CPU
* Gemma 4bit GPU
* Gemma 8bit GPU

Additionally, the sample's source code can be adjusted to experiment with other
inference models from Kaggle as well. To do this, add values to the `LlmModel`
enum and then satisfy all analysis errors for exhaustiveness checks.

### Providing model locations

Once you launch the UI, you will see a model selection screen outlining all the
models declared in the `LlmModel` enum.

<img height="600" src="https://raw.githubusercontent.com/google/flutter-mediapipe/main/assets/empty-models.png" />

> This shows the app in a state where Gemma 4b-CPU has been provided, but not
> the other three.

To remove the red warning and begin using a model, you must run the app with
knowledge of where to download that model using either an environment variable
or `--dart-define`.

> Note: Environment variables are suitable for desktop targets, but as environment
> variables are not forwarded to an attached mobile device, mobile targets require
> using `--dart-define`.

To run this sample, provide the location where you have re-hosted a Gemma model
like so:

```sh
$ flutter run --dart-define=GEMMA_8B_GPU_URI=/path/to/gemma-2b-it-gpu-int8.bin
```

Alternatively, if you are building for desktop, you can use an environment variable
like so:

```sh
$ GEMMA_8B_GPU_URI=/path/to/gemma-2b-it-gpu-int8.bin flutter run
```

#### Downloading model binaries

If you choose to download and rehost models from Kaggle, provide web URLs as values
and the example app will download them at runtime:

```
$ flutter run --dart-define=GEMMA_8B_GPU_URI=https://storage.googleapis.com/your-bucket/gemma-2b-it-gpu-int8.bin
```

#### Pushing model binaries to test devices

Using `adb` on Android or `idb` on iOS, you can push a downloaded binary straight
to your phone's file system and provide an on-disk location via the same parameters.

```sh
$ adb push /path/on/computer/to/gemma-2b-it-gpu-int8.bin /path/on/phone/to/gemma-2b-it-gpu-int8.bin
$ flutter run -d <android_device_id> --dart-define=GEMMA_8B_GPU_URI=/path/on/phone/to/gemma-2b-it-gpu-int8.bin
```

This pattern is useful for local testing, but of course is less suitable for
distributed software.
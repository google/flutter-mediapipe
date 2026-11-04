# mediapipe_retrieval

Google's MediaPipe retrieval tasks for Dart and Flutter. Universal Embedder
turns text, images and audio into vectors in one embedding space; Semantic
Retriever indexes documents, images, audio and mixed records on the device and
finds the ones nearest a query. Every call runs Google's official MediaPipe
pipeline.

## Platforms

| Task | Class | Android | iOS | macOS arm64 | Linux x64 | Windows x64 | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Universal Embedder | `UniversalEmbedder` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Semantic Retriever | `SemanticRetriever` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

The runtimes are Google's MediaPipe 1.2.0: its per-family retrieval C
library, which this package's build hook downloads and checks against its
SHA-256 on Android 9+, iOS 15+, macOS 14+, Linux and Windows, on the CPU; and
`@mediapipe/tasks-retrieval` 1.2.0-rc.20261018 in browsers, on the GPU delegate. Google's
browser Universal Embedder creates a WebGPU device for itself and has no CPU
path
([UP-052](https://github.com/google/flutter-mediapipe/blob/main/upstream-issues.md#up-052-the-browser-universal-embedder-runs-only-on-a-hardware-webgpu-adapter)),
so the capability queries offer browsers only the GPU, and only on a
hardware WebGPU adapter; there both tasks answer as the native library does,
except in WebKit, the engine of Safari and of every browser on iOS, where
Google's runtime returns zeros for every input with both models, so the
queries offer neither task there
([UP-054](https://github.com/google/flutter-mediapipe/blob/main/upstream-issues.md#up-054-in-webkit-the-browser-runtime-embeds-every-input-as-zeros-with-embeddinggemma-2)).
Two more differences the browser runtime imposes: images and audio go in as
bytes and samples there, never as file paths, and the index stays in memory,
so `databasePath` is for the native platforms. In browsers the package fetches
the model itself, since Google's task reads a `modelAssetPath` as a file
([UP-051](https://github.com/google/flutter-mediapipe/blob/main/upstream-issues.md#up-051-the-browser-universal-embedder-reads-modelassetpath-as-a-file-and-a-second-wasm-object-needs-the-loader-again)).

## Quick start

Add `mediapipe_retrieval: ^0.1.0` to your app's dependencies, then:

```dart
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<void> search() async {
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(model: RetrievalModels.embeddingGemma2TextVision),
  );
  final retriever = await SemanticRetriever.create(
    SemanticRetrieverOptions(embedder: embedder),
  );
  try {
    await retriever.insertDocument(
      'dog',
      'A dog chases a ball across the park on a sunny afternoon.',
      metadata: {'topic': 'animals'},
    );
    await retriever.insertDocument(
      'recipe',
      'Whisk the eggs with sugar, then fold in the flour to make the batter.',
      metadata: {'topic': 'cooking'},
    );
    final result = await retriever.retrieve('A puppy playing fetch.', limit: 1);
    print('${result.records.first.id}: ${result.records.first.score}');

    final a = await embedder.embedText('A dog chases a ball.');
    final b = await embedder.embedText('A puppy plays fetch.');
    print(
      UniversalEmbedder.cosineSimilarity(
        a.embeddings.first,
        b.embeddings.first,
      ),
    );
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}
```

`retrieve` returns at most `limit` records scoring at least `minSimilarity`
(Google's default 0.5), best first, each with its id, text, score and
metadata; `metadataFilter` keeps only records carrying every given pair.
`retrieveContent` takes a multimodal query of `TextPart`, `ImagePart` and
`AudioPart`, and `insertImage`, `insertAudio` and `insertContent` index the
other modalities. On Android, iOS and the desktops an image or audio record's
text is the path it was inserted with, or its id when it came from bytes or
samples alone. Audio needs the full model, and Google's audio embeddings vary
slightly from call to call
([UP-058](https://github.com/google/flutter-mediapipe/blob/main/upstream-issues.md#up-058-universal-embedders-audio-embeddings-change-from-call-to-call)).
A retriever runs on its embedder's worker: dispose it before the embedder.

## Models

`RetrievalModels` pins Google's EmbeddingGemma 2 models with a vision encoder,
from Google's LiteRT community on Hugging Face (Apache 2.0): the text and
vision model (`embeddingGemma2TextVision`, 388 MB) and the full model with
audio (`embeddingGemma2`, 485 MB). Both embed into 768 dimensions. Google's
engine refuses the text-only EmbeddingGemma 2 for this task, so it is not
listed. An app bundles a model by naming it under
`hooks.user_defines.mediapipe_retrieval.models` in its pubspec and running
`dart run mediapipe_core:bundle_models`, or passes `modelPath` or
`modelBytes` of its own.

## Capabilities

`queryUniversalEmbedderCapabilities()` and
`querySemanticRetrieverCapabilities()` report, without loading a model, the
delegates this platform runs the tasks on: the CPU on Android, iOS, macOS,
Linux and Windows, and in browsers the GPU, once the plugin has registered
and on a hardware WebGPU adapter. The other delegate is refused by `create`
with a `RuntimeUnavailableException`: the native library's GPU path is not
validated, and Google's browser runtime has no CPU path.

## Testing

`dart test` runs the unit tests and, with Google's model downloaded by
`dart tool/download_models.dart`, the native suite, which compares every
embedding and retrieval with the answers Google's own Python API gave, as
`tool/generate_reference.py` records them: text and images from the official
mediapipe 1.1.0 wheel
(`test/fixtures/embedding_gemma_2_text_vision_reference.json`), and audio,
whose embeddings Google changed in 1.2.0, from its `mediapipe-nightly`
1.2.0rc20261018 wheel, the pinned build
(`test/fixtures/embedding_gemma_2_audio_reference.json`).

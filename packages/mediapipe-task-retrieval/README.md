# mediapipe_retrieval

Google's [MediaPipe] retrieval tasks for Dart and Flutter. Universal Embedder
turns text, images and audio into vectors in one embedding space; Semantic
Retriever indexes documents, images, audio and mixed records on the device and
finds the ones nearest a query. Every call runs Google's official MediaPipe
pipeline.

[MediaPipe]: https://developers.google.com/edge/mediapipe/solutions

## Platforms

| Task | Class | Android | iOS | macOS arm64 | Linux x64 | Windows x64 | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Universal Embedder | `UniversalEmbedder` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Semantic Retriever | `SemanticRetriever` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

The runtimes are Google's MediaPipe 1.2.2: its per-family retrieval C
library, which this package's build hook downloads and checks against its
SHA-256 on Android 9+, iOS 15+, macOS 14+, Linux and Windows, on the CPU; and
`@mediapipe/tasks-retrieval` 1.2.2 in browsers, on the GPU delegate. Google's
browser Universal Embedder creates a WebGPU device for itself and has no CPU
path, so the capability queries offer browsers only the GPU, and only on a
hardware WebGPU adapter; there both tasks answer as the native library does,
except in WebKit, the engine of Safari and of every browser on iOS, where
Google's runtime returns zeros for every input with both models, so the queries
offer neither task there. Two more differences the browser runtime imposes:
images and audio go in as bytes and samples there, never as file paths, and the
index stays in memory, so `databasePath` is for the native platforms. In
browsers the package fetches the model itself, since Google's task reads a
`modelAssetPath` as a file.

## Installation

Add the package from pub.dev, from your app's root:

```sh
flutter pub add mediapipe_retrieval
```

This adds `mediapipe_retrieval: ^0.2.0` to your app's `pubspec.yaml`. `mediapipe_core`
comes with it, and `mediapipe_retrieval.dart` exports its types, so you do not add or
import core yourself.

## Quick start

```dart
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<void> search() async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2TextVision,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  final SemanticRetriever retriever;
  try {
    retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder),
    );
  } catch (_) {
    await embedder.dispose();
    rethrow;
  }
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
slightly from call to call. A retriever runs on its embedder's worker: dispose
it before the embedder.

## Images and audio

Texts and images share one embedding space, so a photo can be compared with
a caption. `embedImage` takes the encoded bytes of a JPEG or PNG, as read
from an asset, a file picker or a download.

```dart
import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<double> captionMatch(Uint8List photo, String caption) async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2TextVision,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  try {
    final image = await embedder.embedImage(photo);
    final text = await embedder.embedText(caption);
    return UniversalEmbedder.cosineSimilarity(
      image.embeddings.first,
      text.embeddings.first,
    );
  } finally {
    await embedder.dispose();
  }
}
```

Scores across modalities run lower than between texts: against the caption
"A dog running across the grass with a ball.", the gallery's dog photo
scores about 0.60 and its cat photo 0.53, close to the retriever's default
`minSimilarity` of 0.5.

A Semantic Retriever indexes images the same way, and `retrieveContent`
finds the records nearest a query made of parts, here a photo.

```dart
import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

/// Prints the indexed [photos] nearest to [query], best first.
Future<void> similarPhotos(
  Map<String, Uint8List> photos,
  Uint8List query,
) async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2TextVision,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  final SemanticRetriever retriever;
  try {
    retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder),
    );
  } catch (_) {
    await embedder.dispose();
    rethrow;
  }
  try {
    for (final MapEntry(key: id, value: bytes) in photos.entries) {
      await retriever.insertImage(id, imageBytes: bytes);
    }
    final result = await retriever.retrieveContent([
      ImagePart(imageBytes: query),
    ], limit: 3);
    for (final record in result.records) {
      print('${record.id}: ${record.score}');
    }
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}
```

Audio needs the full model (`RetrievalModels.embeddingGemma2`). `embedAudio`
takes mono samples in -1 to 1 at 16 kHz, the rate of the clips the package's
tests compare with Google's Python. Google's audio embeddings vary slightly
from call to call, so a score can move by a few thousandths.

```dart
import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<double> soundMatch(Float32List samples, String description) async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  try {
    final sound = await embedder.embedAudio(samples);
    final text = await embedder.embedText(description);
    return UniversalEmbedder.cosineSimilarity(
      sound.embeddings.first,
      text.embeddings.first,
    );
  } finally {
    await embedder.dispose();
  }
}
```

A record can hold several parts. `insertAudio` indexes a sound on its own,
and `insertContent` indexes text, image and audio parts together as one
record; `retrieveContent` takes a query made of parts too, here a recording.

```dart
import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

/// Indexes a sound, a voice memo with its title and a photo with its
/// caption, then finds the record nearest a text and a spoken query.
Future<void> searchMedia({
  required Float32List birdsong,
  required Float32List memo,
  required Uint8List photo,
  required Float32List spokenQuery,
}) async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  final SemanticRetriever retriever;
  try {
    retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder),
    );
  } catch (_) {
    await embedder.dispose();
    rethrow;
  }
  try {
    await retriever.insertAudio('birdsong', audioData: birdsong);
    await retriever.insertContent('memo', [
      TextPart('Voice memo: plans for the weekend.'),
      AudioPart(audioData: memo),
    ]);
    await retriever.insertContent('cat', [
      ImagePart(imageBytes: photo),
      TextPart('Our cat asleep on the sofa.'),
    ]);
    final byText = await retriever.retrieve('A sleeping kitten.', limit: 1);
    print('A sleeping kitten: ${byText.records.first.id}');
    final bySound = await retriever.retrieveContent([
      AudioPart(audioData: spokenQuery),
    ], limit: 1);
    print('The spoken query: ${bySound.records.first.id}');
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}
```

## Managing an index

Metadata narrows a search and removes records in groups. `minSimilarity`
drops the weaker matches, `metadataFilter` keeps only records carrying every
pair it names, and `deleteWithMetadataFilter` removes those records.

```dart
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

Future<void> todoList() async {
  final capabilities = await queryUniversalEmbedderCapabilities();
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(
      model: RetrievalModels.embeddingGemma2TextVision,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  final SemanticRetriever retriever;
  try {
    retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder),
    );
  } catch (_) {
    await embedder.dispose();
    rethrow;
  }
  try {
    final notes = {
      'milk': ('Buy milk and bread.', 'shopping'),
      'eggs': ('Buy a dozen eggs.', 'shopping'),
      'dentist': ('See the dentist on Tuesday at three.', 'calendar'),
      'plumber': ('Call the plumber about the leaking sink.', 'calendar'),
    };
    for (final MapEntry(key: id, value: (text, list)) in notes.entries) {
      await retriever.insertDocument(id, text, metadata: {'list': list});
    }
    final result = await retriever.retrieve(
      'What do I need from the store?',
      limit: 3,
      minSimilarity: 0.6,
      metadataFilter: {'list': 'shopping'},
    );
    for (final record in result.records) {
      print('${record.id}: ${record.score.toStringAsFixed(2)}');
    }
    await retriever.delete('plumber');
    await retriever.deleteWithMetadataFilter({'list': 'shopping'});
    print(await retriever.getAllRecordIds());
    await retriever.deleteAll();
    print(await retriever.getAllRecordIds());
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}
```

Without a `databasePath` the index is kept in memory and goes with the
retriever. On Android, iOS, macOS, Linux and Windows, `databasePath` names a
SQLite file, in a directory the app can write to, that keeps the index
instead, so a retriever created on the same file later finds every record. Browsers keep the index in memory only,
and creating a retriever with a `databasePath` fails there.

```dart
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

/// Adds [note] to the index kept at [databasePath] and prints the id of
/// every note stored there, from this run and earlier ones.
Future<void> keepNote(String databasePath, String id, String note) async {
  final embedder = await UniversalEmbedder.create(
    UniversalEmbedderOptions(model: RetrievalModels.embeddingGemma2TextVision),
  );
  final SemanticRetriever retriever;
  try {
    retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder, databasePath: databasePath),
    );
  } catch (_) {
    await embedder.dispose();
    rethrow;
  }
  try {
    await retriever.insertDocument(id, note);
    print(await retriever.getAllRecordIds());
  } finally {
    await retriever.dispose();
    await embedder.dispose();
  }
}
```

The other options tune Google's pipeline without changing what the calls
return:

| Option | What it does |
| --- | --- |
| `SemanticRetrieverOptions.chunkSize`, `chunkOverlap` | The length of each chunk a document is split into and how much consecutive chunks overlap (Google's 512 and 100). |
| `SemanticRetrieverOptions.chunkingMode` | Whether chunks count characters (`ChunkingMode.character`, the default) or words (`ChunkingMode.word`). |
| `SemanticRetrieverOptions.embeddingDimension` | The embedder's vector size: 768, the default, for both EmbeddingGemma 2 models. |
| `UniversalEmbedderOptions.l2Normalize` | Whether vectors are L2-normalized; on by default, as in Google's browser API. |
| `UniversalEmbedderOptions.maxInputLength` | The most tokens the text encoder reads; 0 keeps the model's default. Google's engine reserves memory for the whole length at create: on a Mac's CPU about 0.4 GB at the default and 6 GB at 4096. |
| `UniversalEmbedderOptions.visionTokensPerImage` | The vision tokens per image; 0 keeps the model's default. |
| `UniversalEmbedderOptions.activationDataType` | The data type the model's activations run in (`ActivationDataType.modelDefault`, `float32`, `float16`, `int16` or `int8`). |
| `UniversalEmbedderOptions.cacheDir` | A directory for compiled model artifacts between runs. |

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

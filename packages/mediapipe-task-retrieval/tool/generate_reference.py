"""Records Google's own answers for the retrieval test cases.

Runs Google's Python Universal Embedder and Semantic Retriever from the
official mediapipe 1.1.0 wheel over the texts and images below and writes
them with the wheel's and model's digests, plus the sizes of Google's C
structs:

    python -I tool/generate_reference.py <embeddinggemma-2-text-vision-440m.litertlm> <output.json>

With --audio, it records the audio cases instead, on the full model, the
only one that embeds audio. Google's audio embeddings changed in 1.2.0, so
they come from its nightly wheel of the pinned build (mediapipe-nightly
1.2.0rc20261018):

    python -I tool/generate_reference.py --audio <embeddinggemma-2-740m.litertlm> <output.json>

The package's tests compare their native answers and struct layouts with
these files.
"""

import ctypes
import importlib.metadata
import json
import pathlib
import platform
import struct
import sys
import wave

from mediapipe.tasks.python.core import base_options as base_options_module
from mediapipe.tasks.python.core import base_options_c
from mediapipe.tasks.python.retrieval import semantic_retriever as sr
from mediapipe.tasks.python.retrieval import universal_embedder as ue

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'mediapipe-core/tool'))
from tool_helpers import compact_json, digest  # noqa: E402

# Six short documents on distinct topics, two of them about animals.
DOCUMENTS = {
    'dog': ('A dog chases a ball across the park on a sunny afternoon.',
            {'topic': 'animals', 'length': 'short'}),
    'recipe': ('Whisk the eggs with sugar, then fold in the flour to make the '
               'cake batter.', {'topic': 'cooking'}),
    'budget': ('The quarterly budget review moved the marketing spend into the '
               'next fiscal year.', {'topic': 'finance'}),
    'stars': ('Astronomers photographed a spiral galaxy two hundred million '
              'light years away.', {'topic': 'space'}),
    'bike': ('Fixing a flat bicycle tire takes a patch kit, a pump and ten '
             'minutes.', {'topic': 'repairs'}),
    'cat': ('The cat slept on the warm windowsill while rain tapped the glass.',
            {'topic': 'animals', 'length': 'short'}),
}

QUERIES = [
    'A puppy playing fetch outside.',
    'How do I bake a cake?',
    'Repairing a bicycle wheel.',
    'Pictures of distant galaxies.',
]

# The gallery's three sample photos, and the sentence its Universal Embedder
# page compares them with; paths are relative to the repository root.
IMAGES = {
    'dog': 'gallery/samples/dog.jpg',
    'cat': 'gallery/samples/cat.png',
    'elephant': 'gallery/samples/elephant.png',
}
IMAGE_TEXT = 'A dog running across the grass with a ball.'

# Two of the audio package's clips, 16 kHz mono, and a sentence for each:
# YAMNet hears speech in the first and a bird in the second. Each is cut to
# its first 15,600 samples (0.975 s), the one length whose embedding Google's
# runtime repeats exactly from call to call (upstream-issues.md UP-058).
AUDIO = {
    'speech': 'packages/mediapipe-task-audio/test/fixtures/speech_16000_hz_mono.wav',
    'bird': 'packages/mediapipe-task-audio/test/fixtures/two_heads_16000_hz_mono.wav',
}
AUDIO_SAMPLES = 15600
AUDIO_TEXTS = ['Someone is talking.', 'A bird is singing.']

STRUCTS = {
    'MpUniversalEmbedderOptions': ue._MpUniversalEmbedderOptionsC,
    'MpBaseOptions': base_options_c.MpBaseOptionsC,
    'MpKeyValuePair': sr._MpKeyValuePairC,
    'MpSemanticRetrieverOptions': sr._MpSemanticRetrieverOptionsC,
    'MpRetrievalRecord': sr._MpRetrievalRecordC,
    'MpRetrievalResult': sr._MpRetrievalResultC,
    'MpRecordIdsResult': sr._MpRecordIdsResultC,
    'MpTextPart': sr._MpTextPartC,
    'MpImagePart': sr._MpImagePartC,
    'MpAudioPart': sr._MpAudioPartC,
    'MpTaskPart': sr._MpTaskPartC,
}


def _vector(result):
  embedding = result.embeddings[0]
  values = getattr(embedding, 'embedding', None)
  if values is None:
    values = embedding.float_embedding
  return [round(float(v), 7) for v in values]


def _records(result):
  return [{'id': r.id, 'text': r.text, 'score': round(float(r.score), 7),
           'metadata': dict(r.metadata)} for r in result.records]


def _media_records(result):
  # Google's Python needs a path for media and keeps it as the record's
  # text; a caller that passes bytes alone gets none, so it is left out.
  return [{'id': r.id, 'score': round(float(r.score), 7),
           'metadata': dict(r.metadata)} for r in result.records]


def _samples(path):
  """Mono 16-bit PCM as the floats Google's audio tasks take, at most
  AUDIO_SAMPLES of them."""
  with wave.open(str(path)) as clip:
    assert clip.getnchannels() == 1 and clip.getsampwidth() == 2, path
    frames = min(clip.getnframes(), AUDIO_SAMPLES)
    return [v / 32768.0 for v in
            struct.unpack(f'<{frames}h', clip.readframes(frames))]


def _wheel_version():
  """The installed release wheel's version, or the nightly wheel's."""
  try:
    return importlib.metadata.version('mediapipe')
  except importlib.metadata.PackageNotFoundError:
    return importlib.metadata.version('mediapipe-nightly')


def _provenance(model, library):
  return {
      'mediapipe': _wheel_version(),
      'platform': f'{platform.system().lower()}/{platform.machine().lower()}',
      'library': library.name,
      'librarySha256': digest(library),
      'model': model.name,
      'modelSha256': digest(model),
  }


def audio_main(model, output):
  embedder = ue.UniversalEmbedder.create_from_options(ue.UniversalEmbedderOptions(
      base_options=base_options_module.BaseOptions(model_asset_path=str(model)),
      l2_normalize=True))
  library = next((pathlib.Path(ue.__file__).parents[2] / 'c').glob('libmediapipe.*'))
  repo = pathlib.Path(__file__).resolve().parents[3]
  texts = {text: embedder.embed_text(text).embeddings[0] for text in AUDIO_TEXTS}
  clips = {}
  for name, path in AUDIO.items():
    result = embedder.embed_audio(_samples(repo / path))
    clips[name] = {
        'path': path,
        'samples': len(_samples(repo / path)),
        'embedding': _vector(result),
        'similarityToTexts': {
            text: round(float(ue.UniversalEmbedder.cosine_similarity(
                vector, result.embeddings[0])), 7)
            for text, vector in texts.items()},
    }
  retriever = sr.SemanticRetriever.create_from_options(sr.SemanticRetrieverOptions(
      embedder=embedder))
  for name, path in AUDIO.items():
    retriever.insert_audio(f'audio:{name}', path, audio_data=_samples(repo / path),
                           metadata={'clip': name})
  retrieval = [{'query': text, 'top2': _media_records(
      retriever.retrieve(text, limit=2, min_similarity=0.0))}
               for text in AUDIO_TEXTS]
  retriever.close()
  embedder.close()
  reference = {**_provenance(model, library), 'audio': clips,
               'audioRetrieval': retrieval}
  output.parent.mkdir(parents=True, exist_ok=True)
  output.write_text(compact_json(reference) + '\n')


def main():
  if sys.argv[1] == '--audio':
    audio_main(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))
    return
  model, output = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
  embedder = ue.UniversalEmbedder.create_from_options(ue.UniversalEmbedderOptions(
      base_options=base_options_module.BaseOptions(model_asset_path=str(model)),
      l2_normalize=True))
  library = pathlib.Path(ue.__file__).parents[2] / 'c'
  library = next(library.glob('libmediapipe.*'))

  texts = {**{f'query:{i}': q for i, q in enumerate(QUERIES)},
           **{f'doc:{k}': v[0] for k, v in DOCUMENTS.items()}}
  embeddings = {name: _vector(embedder.embed_text(text))
                for name, text in texts.items()}
  similarities = {}
  for i, query in enumerate(QUERIES):
    q = embedder.embed_text(query).embeddings[0]
    similarities[f'query:{i}'] = {
        f'doc:{k}': round(float(ue.UniversalEmbedder.cosine_similarity(
            q, embedder.embed_text(v[0]).embeddings[0])), 7)
        for k, v in DOCUMENTS.items()}

  repo = pathlib.Path(__file__).resolve().parents[3]
  images = {}
  sentence = embedder.embed_text(IMAGE_TEXT).embeddings[0]
  for name, path in IMAGES.items():
    result = embedder.embed_image((repo / path).read_bytes())
    images[name] = {
        'path': path,
        'embedding': _vector(result),
        'similarityToText': round(float(ue.UniversalEmbedder.cosine_similarity(
            sentence, result.embeddings[0])), 7),
    }

  retriever = sr.SemanticRetriever.create_from_options(sr.SemanticRetrieverOptions(
      embedder=embedder))
  for doc_id, (text, metadata) in DOCUMENTS.items():
    retriever.insert_document(doc_id, text, metadata)
  retrieval = []
  for query in QUERIES:
    retrieval.append({
        'query': query,
        'top3': _records(retriever.retrieve(query, limit=3, min_similarity=0.0)),
        'default': _records(retriever.retrieve(query, limit=3)),
        'animals': _records(retriever.retrieve(
            query, limit=3, min_similarity=0.0,
            metadata_filter={'topic': 'animals'})),
    })
  all_ids = sorted(retriever.get_all_record_ids())
  retriever.delete_record('cat')
  after_delete = sorted(retriever.get_all_record_ids())
  retriever.delete_with_metadata_filter({'topic': 'animals'})
  after_filter_delete = sorted(retriever.get_all_record_ids())
  retriever.delete_all()
  after_delete_all = sorted(retriever.get_all_record_ids())
  retriever.close()

  # The same photos as image records, searched with the sentence.
  image_retriever = sr.SemanticRetriever.create_from_options(
      sr.SemanticRetrieverOptions(embedder=embedder))
  for name, path in IMAGES.items():
    image_retriever.insert_image(f'image:{name}', path,
                                 image_bytes=(repo / path).read_bytes(),
                                 metadata={'animal': name})
  image_retrieval = {
      'top3': _media_records(image_retriever.retrieve(
          IMAGE_TEXT, limit=3, min_similarity=0.0)),
      'cat': _media_records(image_retriever.retrieve(
          IMAGE_TEXT, limit=3, min_similarity=0.0,
          metadata_filter={'animal': 'cat'})),
  }
  image_retriever.close()
  embedder.close()

  reference = {
      **_provenance(model, library),
      'structSizes': {name: ctypes.sizeof(struct)
                      for name, struct in STRUCTS.items()},
      'texts': texts,
      'embeddings': embeddings,
      'similarities': similarities,
      'imageText': IMAGE_TEXT,
      'images': images,
      'documents': {k: {'text': v[0], 'metadata': v[1]}
                    for k, v in DOCUMENTS.items()},
      'retrieval': retrieval,
      'recordIds': {'all': all_ids, 'afterDeleteCat': after_delete,
                    'afterDeleteAnimals': after_filter_delete,
                    'afterDeleteAll': after_delete_all},
      'imageRetrieval': image_retrieval,
  }
  output.parent.mkdir(parents=True, exist_ok=True)
  output.write_text(compact_json(reference) + '\n')


if __name__ == '__main__':
  main()

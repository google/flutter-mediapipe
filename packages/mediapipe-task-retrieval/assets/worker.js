import {installWorkerQueue, loadVerifiedRuntime, withoutNulls} from
  '../../mediapipe_core/assets/verified_runtime.js';

const loadRuntime = baseUrl =>
  loadVerifiedRuntime(new URL('runtime.json', import.meta.url), baseUrl, 'Retrieval');

let runtime;
let embedder;
// The retrievers built on this embedder, by the id Dart holds.
const retrievers = new Map();
let nextRetriever = 1;
// Core's bridge hands Dart a string; a request without a result gets ''.
installWorkerQueue(run, {reply: result => ({result: result ?? ''})});

async function run(type, input) {
  if (type === 'create') {
    const {modelBytes, modelPath, runtimeBaseUrl, l2Normalize, maxInputLength,
           visionTokensPerImage, activationDataType} = input;
    runtime = await loadRuntime(runtimeBaseUrl);
    // Google's Universal Embedder reads modelAssetPath as a file in its WASM
    // file system rather than fetching a URL, so the model is fetched here
    // and streamed in, as Google's LLM APIs take their large models.
    let modelAssetBuffer = modelBytes;
    if (!modelAssetBuffer) {
      const response = await fetch(modelPath);
      if (!response.ok) throw new Error(`Model download failed: HTTP ${response.status} for ${modelPath}`);
      modelAssetBuffer = response.body.getReader();
    }
    embedder = await runtime.bundle.UniversalEmbedder.createFromOptions(runtime.files, {
      baseOptions: {modelAssetBuffer},
      ...withoutNulls({l2Normalize, maxInputLength, visionTokensPerImage, activationDataType}),
    });
    return null;
  }
  if (type === 'close') {
    for (const retriever of retrievers.values()) retriever.close();
    retrievers.clear();
    embedder?.close();
    embedder = undefined;
    return null;
  }
  if (!embedder) throw new Error('MediaPipe Universal Embedder is closed');
  switch (input.method) {
    case 'embedText':
      return JSON.stringify(embedding(await embedder.embedText(input.text)));
    case 'embedImage':
      return JSON.stringify(embedding(await embedder.embedImage(input.imageBytes)));
    case 'embedAudio':
      return JSON.stringify(embedding(await embedder.embedAudio(input.audioData)));
    case 'retriever.create': {
      if (input.databasePath) {
        throw new Error('Semantic Retriever keeps its index in memory in browsers; databasePath is for the native platforms');
      }
      const {SemanticRetriever, SemanticRetrieverComponents, MemoryVectorStore} = runtime.bundle;
      // The same chunker as Google's native default, so documents split alike.
      const chunker = await textChunker(input.chunkSize, input.chunkOverlap, input.chunkingMode.toUpperCase());
      const components = new SemanticRetrieverComponents()
        .addProvider(embedder.getProvider())
        .setVectorStore(new MemoryVectorStore())
        .setTextChunker(chunker);
      const id = nextRetriever++;
      retrievers.set(id, await SemanticRetriever.createFromComponents(components));
      return JSON.stringify({id});
    }
  }
  const retriever = retrievers.get(input.retriever);
  if (!retriever) throw new Error('MediaPipe Semantic Retriever is closed');
  const metadata = withoutNulls(input.metadata ?? {});
  switch (input.method) {
    case 'retriever.insertDocument':
      await retriever.insertDocument(input.recordId, input.text, metadata);
      return null;
    case 'retriever.insertImage':
      await retriever.insertImage(input.recordId, imageBytes(input), metadata);
      return null;
    case 'retriever.insertAudio':
      await retriever.insertAudio(input.recordId, audioData(input), metadata);
      return null;
    case 'retriever.insertContent':
      await retriever.insertContent(input.recordId, input.parts.map(part), metadata);
      return null;
    case 'retriever.retrieve': {
      const results = await retriever.retrieve(input.parts.map(part), {
        limit: input.limit,
        ...(input.metadataFilter ? {metadataFilter: input.metadataFilter} : {}),
      });
      // Google's native API takes the threshold itself; its browser API has
      // none, so the same cut is applied here.
      return JSON.stringify({records: results
        .filter(result => result.score >= input.minSimilarity)
        .map(result => ({
          id: result.id,
          text: result.content.filter(p => 'text' in p).map(p => p.text).join('\n'),
          score: result.score,
          metadata: result.metadata ?? {},
        }))});
    }
    case 'retriever.delete':
      await retriever.delete(input.recordId);
      return null;
    case 'retriever.deleteWithMetadataFilter':
      await retriever.delete(input.metadataFilter);
      return null;
    case 'retriever.deleteAll':
      await retriever.deleteAll();
      return null;
    case 'retriever.getAllRecordIds':
      return JSON.stringify({ids: await retriever.getAllRecordIds()});
    case 'retriever.close':
      retriever.close();
      retrievers.delete(input.retriever);
      return null;
  }
  throw new Error('Unsupported retrieval request: ' + input.method);
}

// Google's chunker runs in the retrieval Wasm module. The embedder already
// holds one, so the chunker shares it when the module can be found on the
// embedder (its field is minified, so it is found by shape). Otherwise the
// module is loaded again from a fresh copy of the loader script: the bundle
// reads the factory a loader sets only the first time a URL is imported.
async function textChunker(chunkSize, chunkOverlap, mode) {
  const {DefaultTextChunker} = runtime.bundle;
  const shared = Object.values(embedder).find(
    value => value && typeof value.defaultTextChunker_nativeChunkText === 'function');
  if (shared) return DefaultTextChunker.createFromModule(shared, chunkSize, chunkOverlap, mode);
  const loader = await (await fetch(runtime.files.wasmLoaderPath)).text();
  const url = URL.createObjectURL(new Blob([loader], {type: 'text/javascript'}));
  try {
    return await DefaultTextChunker.create(
      {...runtime.files, wasmLoaderPath: url}, chunkSize, chunkOverlap, mode);
  } finally {
    URL.revokeObjectURL(url);
  }
}

// Google's result with typed arrays as plain arrays, which JSON keeps.
function embedding(result) {
  return {embeddings: (result.embeddings ?? []).map(e => ({
    floatEmbedding: e.floatEmbedding ? Array.from(e.floatEmbedding) : null,
    quantizedEmbedding: e.quantizedEmbedding ? Array.from(e.quantizedEmbedding) : null,
    headIndex: e.headIndex ?? 0,
    headName: e.headName ?? '',
  }))};
}

function imageBytes(input) {
  if (!input.imageBytes) throw new Error('Browsers take image bytes; filePath is for the native platforms');
  return input.imageBytes;
}

function audioData(input) {
  if (!input.audioData) throw new Error('Browsers take audio samples; audioPath is for the native platforms');
  return input.audioData;
}

// A Dart part as Google's ContentPart.
function part(p) {
  if (p.kind === 'text') return {text: p.text};
  if (p.kind === 'image') return {imageBytes: imageBytes(p)};
  return {audioData: audioData(p)};
}

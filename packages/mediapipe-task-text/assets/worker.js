import {installWorkerQueue, loadVerifiedRuntime, withoutNulls} from
  '../../mediapipe_core/assets/verified_runtime.js';

const loadRuntime = baseUrl =>
  loadVerifiedRuntime(new URL('runtime.json', import.meta.url), baseUrl, 'Text');

// Google's class and the method that runs one request, per task. The
// embedder's optional format context arrives as Google's `TextFormatOptions`.
const taskSpecs = (TextClassifier, TextEmbedder, LanguageDetector) => ({
  text_classifier: {type: TextClassifier, run: (task, input) => task.classify(input.text)},
  text_embedder: {type: TextEmbedder, run: (task, input) => task.embed(input.text, input.formatContext)},
  language_detector: {type: LanguageDetector, run: (task, input) => task.detect(input.text)},
});

let task;
let spec;
installWorkerQueue(run);

async function run(type, input) {
  if (type === 'create') {
    const {task: name, modelBytes, modelPath, delegate = 'CPU', runtimeBaseUrl, ...settings} = input;
    const {bundle: {LanguageDetector, TextClassifier, TextEmbedder}, files} =
      await loadRuntime(runtimeBaseUrl);
    spec = taskSpecs(TextClassifier, TextEmbedder, LanguageDetector)[name];
    if (!spec) throw new Error('Unsupported MediaPipe text task: ' + name);
    task = await spec.type.createFromOptions(files, {
      ...withoutNulls(settings),
      baseOptions: {delegate, ...(modelBytes ? {modelAssetBuffer: modelBytes} : {modelAssetPath: modelPath})},
    });
    return null;
  }
  if (type === 'close') {
    task?.close();
    task = undefined;
    return null;
  }
  if (!task) throw new Error('MediaPipe text task is closed');
  // Quantized embeddings are typed arrays, which JSON would turn into objects.
  return JSON.stringify(spec.run(task, input),
    (_, value) => value instanceof Uint8Array ? Array.from(value) : value);
}

import {installWorkerQueue, loadVerifiedRuntime, withoutNulls} from
  '../../mediapipe_core/assets/verified_runtime.js';

const loadRuntime = baseUrl =>
  loadVerifiedRuntime(new URL('runtime.json', import.meta.url), baseUrl, 'Audio');

let task;
installWorkerQueue(run);

async function run(type, input) {
  if (type === 'create') {
    const {modelBytes, modelPath, delegate = 'CPU', runtimeBaseUrl, ...settings} = input;
    const {bundle: {AudioClassifier}, files} = await loadRuntime(runtimeBaseUrl);
    task = await AudioClassifier.createFromOptions(files, {
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
  if (!task) throw new Error('MediaPipe audio task is closed');
  // One result per chunk the model reads, in order.
  return JSON.stringify(task.classify(input.samples, input.sampleRate));
}

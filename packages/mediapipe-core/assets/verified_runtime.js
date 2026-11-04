// Loads a family's pinned MediaPipe browser runtime, checking every file
// against its SHA-384 in runtime.json before the browser runs it: the same
// bytes are required from jsDelivr, a self-hosted root or a mirror. Only the
// bundle and the one WASM variant this browser uses are fetched. The verified
// WASM bytes come back too, for a caller that compiles them ahead of a task.
export async function loadVerifiedRuntime(pinUrl, baseUrl, family) {
  const response = await fetch(pinUrl);
  if (!response.ok) throw new Error(`Unable to load MediaPipe runtime pin: HTTP ${response.status}`);
  const pin = await response.json();
  const base = new URL(`${pin.package}@${pin.version}/`, baseUrl);
  const urls = [];
  let wasmBytes;
  async function verified(name) {
    const expected = pin.sha384[name];
    if (!expected) throw new Error(`MediaPipe runtime ${name}: not pinned`);
    // TODO: Try the package's own copy, then fallback roots, retrying
    // transient failures; one failed fetch fails the task today. See
    // packages/mediapipe-core/tool/ASSET_HOSTING.md.
    const file = await fetch(new URL(name, base));
    if (!file.ok) throw new Error(`MediaPipe runtime ${name}: HTTP ${file.status}`);
    const bytes = await file.arrayBuffer();
    const digest = new Uint8Array(await crypto.subtle.digest('SHA-384', bytes));
    if (btoa(String.fromCharCode(...digest)) !== expected) {
      throw new Error(`MediaPipe runtime ${name}: SHA-384 mismatch`);
    }
    if (name.endsWith('.wasm')) wasmBytes = bytes;
    const url = URL.createObjectURL(new Blob([bytes], {
      type: name.endsWith('.wasm') ? 'application/wasm' : 'text/javascript',
    }));
    urls.push(url);
    return url;
  }
  // Google's usage logs name the host from this global (FLUTTER_WEB = 6 in
  // its HostEnvironment enum, read from @mediapipe/tasks-* 1.2.0-rc.20261017
  // on); without it they report a plain web page (WEB = 4).
  globalThis.__HOST_ENVIRONMENT__ = 'FLUTTER_WEB';
  try {
    const bundle = await import(await verified(`${family.toLowerCase()}_bundle.mjs`));
    // The resolver only picks the variant this browser supports (SIMD or
    // not); it fetches nothing given a relative root.
    const paths = await bundle.FilesetResolver[`for${family}Tasks`]('wasm', true);
    const name = path => `wasm/${path.split('/').pop()}`;
    const files = {
      wasmLoaderPath: await verified(name(paths.wasmLoaderPath)),
      wasmBinaryPath: await verified(name(paths.wasmBinaryPath)),
    };
    return {bundle, files, wasmBytes};
  } catch (error) {
    for (const url of urls) URL.revokeObjectURL(url);
    throw error;
  }
}

// Runs each request a family's worker receives after the one before it, so
// creation, requests and shutdown keep their order, and replies under the
// request's id with what reply makes of run's result, or with its error.
// transfers names what the reply hands over rather than copies.
export function installWorkerQueue(run, {reply = result => ({result}), transfers = () => []} = {}) {
  let operations = Promise.resolve();
  self.onmessage = ({data}) => {
    operations = operations.then(async () => {
      try {
        const result = await run(data.type, data.input);
        self.postMessage({id: data.id, ...reply(result)}, transfers(result));
      } catch (error) {
        self.postMessage({id: data.id, error: error?.message || String(error)});
      }
    });
  };
}

// Dart sends absent settings as null; Google's API wants them left out.
export function withoutNulls(settings) {
  return Object.fromEntries(Object.entries(settings).filter(([, value]) => value != null));
}

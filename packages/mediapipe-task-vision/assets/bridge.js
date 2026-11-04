// One worker owns each official task. The UI never performs synchronous inference.
(() => {
  const base = new URL('.', document.currentScript.src);
  const workers = new Map();
  let next = 0;
  let totalCreated = 0;
  let totalClosed = 0;
  // Once a page has closed a task it is switching between them, so one spare
  // worker loads, verifies and compiles Google's runtime ahead of the next:
  // that task then only instantiates it. Nothing is spared for a page that
  // keeps its one task.
  let spare;
  let switching = false;
  let spareTimer;
  function spawn() {
    return new Worker(new URL('worker.js', base), {type: 'module'});
  }
  function prepareSpare(runtimeBaseUrl, delay) {
    clearTimeout(spareTimer);
    spareTimer = setTimeout(() => {
      if (spare || !runtimeBaseUrl) return;
      const worker = spawn();
      // A spare that fails is dropped rather than handed to the next task,
      // whose create would otherwise wait on a dead worker until it timed out.
      worker.onerror = event => {
        event.preventDefault();
        if (spare?.worker !== worker) return;
        spare = undefined;
        worker.terminate();
      };
      worker.postMessage({id: -1, type: 'preload', input: {runtimeBaseUrl}});
      spare = {worker, runtimeBaseUrl};
    }, delay);
  }
  function takeWorker(runtimeBaseUrl) {
    const ready = spare;
    spare = undefined;
    if (ready?.runtimeBaseUrl === runtimeBaseUrl) return ready.worker;
    ready?.worker.terminate();
    return spawn();
  }
  function fail(state, error) {
    if (state.dead) return;
    state.dead = true;
    state.worker.terminate();
    workers.delete(state.id);
    totalClosed++;
    for (const pending of state.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    state.pending.clear();
  }
  function request(state, type, input) {
    if (state.dead) {
      input?.bitmap?.close();
      return Promise.reject(new Error('MediaPipe worker is closed'));
    }
    return new Promise((resolve, reject) => {
      const id = state.next++;
      const timer = setTimeout(() => fail(state, new Error('MediaPipe worker request timed out')), 120000);
      state.pending.set(id, {resolve, reject, timer});
      const transfers = [];
      if (input?.bitmap) transfers.push(input.bitmap);
      if (input?.pixels) transfers.push(input.pixels.buffer);
      if (input?.modelBytes) transfers.push(input.modelBytes.buffer);
      if (input?.overlay) transfers.push(input.overlay);
      try {
        state.worker.postMessage({id, type, input}, transfers);
      } catch (error) {
        clearTimeout(timer);
        state.pending.delete(id);
        input?.bitmap?.close();
        reject(error);
      }
    });
  }
  globalThis.mediapipeVision = {
    async create(options) {
      const worker = takeWorker(options.runtimeBaseUrl);
      const id = next++;
      const state = {id, worker, runtimeBaseUrl: options.runtimeBaseUrl,
        pending: new Map(), next: 0, dead: false,
        overlayActive: false, overlayOptions: {connections: true, points: false}};
      workers.set(id, state);
      totalCreated++;
      worker.onmessage = ({data}) => {
        const pending = state.pending.get(data.id);
        if (!pending) return;
        clearTimeout(pending.timer);
        state.pending.delete(data.id);
        if (data.overlayFailed) state.overlayActive = false;
        if (data.error) pending.reject(new Error(data.error));
        else pending.resolve(data.result);
      };
      worker.onerror = event => {
        event.preventDefault();
        fail(state, new Error(event.message || 'MediaPipe worker failed'));
      };
      worker.onmessageerror = () => fail(state, new Error('Invalid MediaPipe worker response'));
      try {
        await request(state, 'create', options);
        // After this task's warm-up rather than during it.
        if (switching) prepareSpare(options.runtimeBaseUrl, 3000);
        return id;
      } catch (error) {
        fail(state, error);
        throw error;
      }
    },
    detect(id, input) {
      const state = workers.get(id);
      if (!state) {
        input.bitmap?.close();
        return Promise.reject(new Error('MediaPipe task is closed'));
      }
      if (state.overlayActive) input.overlayOptions = state.overlayOptions;
      return request(state, 'detect', input);
    },
    async attachOverlay(id, canvas) {
      const state = workers.get(id);
      if (!state || typeof canvas.transferControlToOffscreen !== 'function') {
        throw new Error('Worker canvas overlay is unavailable');
      }
      const overlay = canvas.transferControlToOffscreen();
      await request(state, 'overlay', {overlay});
      state.overlayActive = true;
    },
    async detachOverlay(id) {
      const state = workers.get(id);
      if (!state) return;
      state.overlayActive = false;
      await request(state, 'overlay', {overlay: null});
    },
    setOverlayOptions(id, options) {
      const state = workers.get(id);
      if (state) state.overlayOptions = options;
    },
    overlayActive(id) { return workers.get(id)?.overlayActive ?? false; },
    async close(id) {
      const state = workers.get(id);
      if (!state) return;
      // The next task is likely on its way: start loading it a runtime now.
      switching = true;
      prepareSpare(state.runtimeBaseUrl, 0);
      try { await request(state, 'close'); }
      finally { fail(state, new Error('MediaPipe task is closed')); }
    },
    // Read-only diagnostics used by release-browser tests.
    stats() {
      return {activeWorkers: workers.size, spareWorkers: spare ? 1 : 0, totalCreated, totalClosed,
        activeOverlays: [...workers.values()].filter(s => s.overlayActive).length,
        pendingRequests: [...workers.values()].reduce((n, s) => n + s.pending.size, 0)};
    },
  };
})();

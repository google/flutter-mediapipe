// One worker owns each official text or audio task, so inference never blocks
// the UI. Each family supplies its worker script, which loads Google's
// runtime and runs its tasks; this bridge only owns the workers and their
// requests. Vision keeps its own bridge for frames and overlays.
(() => {
  if (globalThis.mediapipeTasks) return;
  const workers = new Map();
  let next = 0;
  function fail(state, error) {
    if (state.dead) return;
    state.dead = true;
    state.worker.terminate();
    workers.delete(state.id);
    for (const pending of state.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    state.pending.clear();
  }
  function request(state, type, input) {
    if (state.dead) return Promise.reject(new Error('MediaPipe worker is closed'));
    return new Promise((resolve, reject) => {
      const id = state.next++;
      // Creation fetches the model, which for Decision Maker is 680 MB.
      const limit = type === 'create' ? 600000 : 120000;
      const timer = setTimeout(() => fail(state, new Error('MediaPipe worker request timed out')), limit);
      state.pending.set(id, {resolve, reject, timer});
      const transfers = [];
      if (input?.modelBytes) transfers.push(input.modelBytes.buffer);
      if (input?.samples) transfers.push(input.samples.buffer);
      try {
        state.worker.postMessage({id, type, input}, transfers);
      } catch (error) {
        clearTimeout(timer);
        state.pending.delete(id);
        reject(error);
      }
    });
  }
  globalThis.mediapipeTasks = {
    async create(workerUrl, options) {
      const worker = new Worker(workerUrl, {type: 'module'});
      const id = next++;
      const state = {id, worker, pending: new Map(), next: 0, dead: false};
      workers.set(id, state);
      worker.onmessage = ({data}) => {
        const pending = state.pending.get(data.id);
        if (!pending) return;
        clearTimeout(pending.timer);
        state.pending.delete(data.id);
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
        return id;
      } catch (error) {
        fail(state, error);
        throw error;
      }
    },
    run(id, input) {
      const state = workers.get(id);
      if (!state) return Promise.reject(new Error('MediaPipe task is closed'));
      return request(state, 'run', input);
    },
    async close(id) {
      const state = workers.get(id);
      if (!state) return;
      try { await request(state, 'close'); }
      finally { fail(state, new Error('MediaPipe task is closed')); }
    },
    // Read-only diagnostics for the browser tests.
    stats() {
      return {activeWorkers: workers.size,
        pendingRequests: [...workers.values()].reduce((n, s) => n + s.pending.size, 0)};
    },
  };
})();

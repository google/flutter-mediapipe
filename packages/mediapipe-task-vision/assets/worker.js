let FilesetResolver, FaceDetector, FaceLandmarker, GestureRecognizer, HandLandmarker;
let HolisticLandmarker, ImageClassifier, ImageEmbedder, ImageSegmenter;
let InteractiveSegmenter, ObjectDetector, PoseLandmarker;
let DrawingUtils;

import {installWorkerQueue, loadVerifiedRuntime} from
  '../../mediapipe_core/assets/verified_runtime.js';

// The runtime this worker loaded, once: a spare worker loads it before any
// task is asked of it (see 'preload' and the bridge's prepareSpare).
let runtime;
function loadRuntime(baseUrl) {
  if (runtime?.baseUrl !== baseUrl) {
    const load = (async () => {
      const {bundle, files, wasmBytes} = await loadVerifiedRuntime(
        new URL('runtime.json', import.meta.url), baseUrl, 'Vision');
      ({FilesetResolver, FaceDetector, FaceLandmarker, GestureRecognizer, HandLandmarker,
        HolisticLandmarker, ImageClassifier, ImageEmbedder, ImageSegmenter,
        InteractiveSegmenter, ObjectDetector, PoseLandmarker,
        DrawingUtils} = bundle);
      // Compiling Google's WASM here, rather than inside createFromOptions,
      // lets a spare worker do it before the page asks for a task. A browser
      // that refuses leaves the loader to compile it as before.
      let module = null;
      try {
        if (wasmBytes) module = await WebAssembly.compile(wasmBytes);
      } catch (_) {}
      return {files, module};
    })();
    runtime = {baseUrl, load};
    // A failed load (offline, say) is retried by the next request.
    load.catch(() => { if (runtime?.load === load) runtime = undefined; });
  }
  return runtime.load;
}

let overlay;
let drawing;

function drawOverlay(result, width, height, options) {
  if (overlay.width !== width || overlay.height !== height) {
    overlay.width = width;
    overlay.height = height;
  }
  const context = overlay.getContext('2d');
  context.clearRect(0, 0, width, height);
  const accent = '#8cd0d6', white = '#ffffff';
  // The preview is mirrored independently. Mirror only the shapes here, so
  // labels stay readable, and keep stroke sizes in displayed CSS pixels.
  const pixel = Number.isFinite(options.scale) && options.scale > 0 ? 1 / options.scale : 1;
  const lines = (points, edges, color, lineWidth = 2) => {
    if (options.connections && points?.length) {
      drawing.drawConnectors(points, edges, {color, lineWidth: lineWidth * pixel});
    }
  };
  const dots = (points, color, radius = 2.5) => {
    if (options.points && points?.length) {
      drawing.drawLandmarks(points, {color, radius: radius * pixel});
    }
  };
  const label = (text, x, y, color, size = 16) => {
    context.save();
    if (options.mirrored) context.setTransform(1, 0, 0, 1, 0, 0);
    context.font = `600 ${size * pixel}px sans-serif`;
    context.fillStyle = color;
    context.shadowColor = '#000000';
    context.shadowBlur = 3 * pixel;
    context.fillText(text, x, y);
    context.restore();
  };
  const hand = (points, index) => {
    const color = index === 0 ? accent : white;
    lines(points, HandLandmarker.HAND_CONNECTIONS, color);
    dots(points, color);
  };
  const pose = points => {
    lines(points, PoseLandmarker.POSE_CONNECTIONS, accent);
    dots(points, accent);
  };
  context.save();
  if (options.mirrored) {
    context.translate(width, 0);
    context.scale(-1, 1);
  }
  try {
    switch (spec.name) {
    case 'FaceLandmarker':
      for (const face of result.faceLandmarks ?? []) {
        lines(face, FaceLandmarker.FACE_LANDMARKS_TESSELATION, '#8cd0d673', 0.7);
        lines(face, FaceLandmarker.FACE_LANDMARKS_CONTOURS, accent, 1.5);
        lines(face, FaceLandmarker.FACE_LANDMARKS_LEFT_IRIS, white, 1.8);
        lines(face, FaceLandmarker.FACE_LANDMARKS_RIGHT_IRIS, white, 1.8);
        dots(face, white, 1.4);
      }
      break;
    case 'HandLandmarker':
      (result.landmarks ?? []).forEach(hand);
      break;
    case 'GestureRecognizer':
      (result.landmarks ?? []).forEach((points, index) => {
        hand(points, index);
        const name = result.gestures?.[index]?.[0]?.categoryName;
        if (name && points.length) {
          label(name, (options.mirrored ? 1 - points[0].x : points[0].x) * width + 8 * pixel,
            points[0].y * height + 24 * pixel, index === 0 ? accent : white);
        }
      });
      break;
    case 'PoseLandmarker':
      (result.landmarks ?? []).forEach(pose);
      break;
    case 'HolisticLandmarker':
      // Each part lists one set of points per person, as packParts reads it.
      (result.poseLandmarks ?? []).forEach(pose);
      (result.leftHandLandmarks ?? []).forEach(points => hand(points, 0));
      (result.rightHandLandmarks ?? []).forEach(points => hand(points, 1));
      for (const face of result.faceLandmarks ?? []) {
        lines(face, FaceLandmarker.FACE_LANDMARKS_CONTOURS, white);
        dots(face, white);
      }
      break;
    case 'FaceDetector':
    case 'ObjectDetector':
      for (const detection of result.detections ?? []) {
        const box = detection.boundingBox;
        if (!box) continue;
        if (options.connections) {
          drawing.drawBoundingBox(box, {
            color: accent, fillColor: 'transparent', lineWidth: 2 * pixel,
          });
          const category = detection.categories?.[0];
          const name = spec.name === 'FaceDetector' ? 'face' : category?.categoryName ?? '?';
          const score = Math.round((category?.score ?? 0) * 100);
          const left = options.mirrored ? width - box.originX - box.width : box.originX;
          label(`${name} ${score}%`, left + 4 * pixel,
            box.originY + 19 * pixel, accent, 15);
        }
        if (options.points) dots(detection.keypoints, accent, 3);
      }
      break;
    }
  } finally {
    context.restore();
  }
}

// Each task: Google's class, its IMAGE and VIDEO methods, and the result field
// holding its image landmarks, which travel packed; everything else in the
// result travels as JSON. Holistic's landmark parts travel packed together
// (packParts). Mask fields name their bytes per value; masks travel as
// transferred buffers.
function buildTasks() { return {
  face_landmarker: {name: 'FaceLandmarker', type: FaceLandmarker, landmarks: 'faceLandmarks'},
  hand_landmarker: {name: 'HandLandmarker', type: HandLandmarker, landmarks: 'landmarks'},
  pose_landmarker: {name: 'PoseLandmarker', type: PoseLandmarker, landmarks: 'landmarks',
    masks: {segmentationMasks: 4}},
  gesture_recognizer: {name: 'GestureRecognizer', type: GestureRecognizer, landmarks: 'landmarks',
    image: 'recognize', video: 'recognizeForVideo'},
  holistic_landmarker: {name: 'HolisticLandmarker', type: HolisticLandmarker,
    parts: ['faceLandmarks', 'poseLandmarks', 'poseWorldLandmarks', 'leftHandLandmarks',
      'leftHandWorldLandmarks', 'rightHandLandmarks', 'rightHandWorldLandmarks'],
    masks: {poseSegmentationMasks: 4}},
  face_detector: {name: 'FaceDetector', type: FaceDetector, boxes: true},
  object_detector: {name: 'ObjectDetector', type: ObjectDetector, boxes: true},
  image_classifier: {name: 'ImageClassifier', type: ImageClassifier,
    image: 'classify', video: 'classifyForVideo'},
  // Quantized embeddings are typed arrays, which JSON would turn into objects.
  image_embedder: {name: 'ImageEmbedder', type: ImageEmbedder,
    image: 'embed', video: 'embedForVideo',
    json: result => ({...result, embeddings: result.embeddings.map(e => ({
      ...e,
      floatEmbedding: e.floatEmbedding && Array.from(e.floatEmbedding),
      quantizedEmbedding: e.quantizedEmbedding && Array.from(e.quantizedEmbedding),
    }))})},
  image_segmenter: {name: 'ImageSegmenter', type: ImageSegmenter,
    image: 'segment', video: 'segmentForVideo',
    masks: {confidenceMasks: 4, categoryMask: 1}, labels: true,
    json: result => ({...result, qualityScores: result.qualityScores && Array.from(result.qualityScores)})},
  // Stateful MagicTouch: setImage keeps an image, then each request carries a
  // full stroke history and returns one float mask.
  interactive_segmenter: {name: 'InteractiveSegmenter', type: InteractiveSegmenter,
    stateful: true},
}; }

let task;
let labels;
let spec;
// Masks and landmarks move to the page rather than being copied.
installWorkerQueue(run, {
  reply: result => ({result, overlayFailed: result?.overlayFailed}),
  transfers: result => [...(result?.masks ?? []),
    ...(result?.landmarks ? [result.landmarks.buffer] : [])],
});
async function run(type, input) {
  if (type === 'overlay') {
    if (!input.overlay) {
      overlay = drawing = undefined;
      return null;
    }
    overlay = input.overlay;
    const context = overlay.getContext('2d');
    if (!context) throw new Error('Worker canvas 2D context is unavailable');
    drawing = new DrawingUtils(context);
    return null;
  }
  if (type === 'preload') {
    await loadRuntime(input.runtimeBaseUrl);
    return null;
  }
  if (type === 'create') {
    const {modelBytes, modelPath, delegate, runtimeBaseUrl, task: name = 'face_landmarker', ...settings} = input;
    const {files, module} = await loadRuntime(runtimeBaseUrl);
    const TASKS = buildTasks();
    spec = TASKS[name];
    if (!spec) throw new Error('Unsupported MediaPipe task: ' + name);
    if (delegate !== 'CPU' && delegate !== 'GPU') throw new Error('Invalid ' + spec.name + ' delegate');
    if (typeof OffscreenCanvas === 'undefined') {
      throw new Error(spec.name + ' requires OffscreenCanvas in a browser worker.');
    }
    // The bundled runtime picks its own canvas by sniffing the user agent, and
    // reads every WebKit browser without a Version/NN token as Safari 16. Firefox
    // and Chrome on iOS land there, and its fallback calls document.createElement
    // inside a worker, where there is no document. Supplying the canvas keeps that
    // branch unreachable.
    const canvas = new OffscreenCanvas(1, 1);
    if (delegate === 'GPU' && !canvas.getContext('webgl2')) {
      throw new Error('GPU ' + spec.name + ' requires WebGL 2 in a browser worker. Select CPU or enable browser hardware acceleration.');
    }
    // Google's loader instantiates the precompiled module through this hook
    // instead of fetching and compiling the WASM again, and clears it after.
    // Synchronous, so a failure rejects createFromOptions.
    if (module) {
      self.Module = {
        instantiateWasm: (imports, receive) =>
          receive(new WebAssembly.Instance(module, imports), module),
      };
    }
    try {
      task = await spec.type.createFromOptions(files, {
        ...settings,
        canvas,
        baseOptions: {
          delegate,
          ...(modelBytes ? {modelAssetBuffer: modelBytes} : {modelAssetPath: modelPath}),
        },
      });
    } finally {
      self.Module = undefined;
    }
    labels = spec.labels ? task.getLabels() : undefined;
    return null;
  }
  if (type === 'close') {
    task?.close();
    task = undefined;
    overlay = drawing = undefined;
    return null;
  }
  let source = input.bitmap;
  let owned = input.bitmap;
  try {
    if (!task) throw new Error(spec.name + ' is closed');
    if (spec.stateful && input.strokes) return segmentStrokes(input.strokes);
    if (input.path) {
      const response = await fetch(input.path);
      if (!response.ok) throw new Error('Image load failed: ' + response.status);
      source = owned = await createImageBitmap(await response.blob());
    } else if (input.pixels) {
      const rgba = new Uint8ClampedArray(input.width * input.height * 4);
      const channels = input.format === 'rgb' ? 3 : 4;
      const bgra = input.format === 'bgra';
      for (let y = 0; y < input.height; y++) {
        for (let x = 0; x < input.width; x++) {
          const from = y * input.stride + x * channels;
          const to = (y * input.width + x) * 4;
          rgba[to] = input.pixels[from + (bgra ? 2 : 0)];
          rgba[to + 1] = input.pixels[from + 1];
          rgba[to + 2] = input.pixels[from + (bgra ? 0 : 2)];
          rgba[to + 3] = channels === 3 ? 255 : input.pixels[from + 3];
        }
      }
      source = new ImageData(rgba, input.width, input.height);
    }
    if (spec.stateful) {
      task.setImage(source);
      return {json: JSON.stringify({result: {}})};
    }
    const processing = {rotationDegrees: ((input.rotation % 360) + 360) % 360};
    if (input.region) {
      const [left, top, right, bottom] = input.region;
      processing.regionOfInterest = {left, top, right, bottom};
    }
    const result = input.timestamp == null
        ? task[spec.image ?? 'detect'](source, processing)
        : task[spec.video ?? 'detectForVideo'](source, input.timestamp, processing);
    const packed = spec.landmarks ? pack(result[spec.landmarks] ?? [])
      : spec.parts ? packParts(result, spec.parts) : null;
    const masks = [];
    let plain = spec.json ? spec.json(result) : result;
    try {
      plain = {...plain, ...copyMasks(result, masks)};
    } finally {
      closeMasks(result);
    }
    if (labels) plain.labels = labels;
    const emptied = packed
      ? Object.fromEntries((spec.parts ?? [spec.landmarks]).map(field => [field, []])) : {};
    const json = JSON.stringify({width: source.width, height: source.height,
      timestamp: input.timestamp, counts: packed?.counts, parts: packed?.parts,
      result: {...plain, ...emptied}});
    let overlayFailed = false;
    if (drawing && input.overlayOptions && (spec.landmarks || spec.parts || spec.boxes)) {
      try {
        drawOverlay(result, source.width, source.height, input.overlayOptions);
      } catch (error) {
        // Inference succeeded. Keep delivering results and let the gallery's
        // Flutter painter take over on the next frame.
        console.warn('Worker overlay failed; using Flutter painter', error);
        overlay = drawing = undefined;
        overlayFailed = true;
      }
    }
    return {json, landmarks: packed?.values, masks, overlayFailed};
  } finally {
    owned?.close();
  }
}
// Each stroke arrives as [brush mode, [x, y, ...], completed]; the modes are
// Google's numeric BrushMode values.
function segmentStrokes(strokes) {
  const mask = task.segment(strokes.map(([brushMode, xy, isCompleted]) => ({
    brushMode, isCompleted,
    point: Array.from({length: xy.length >> 1}, (_, i) => ({x: xy[2 * i], y: xy[2 * i + 1]})),
  })));
  try {
    const values = mask.getAsFloat32Array().slice();
    return {json: JSON.stringify({result: {confidenceMasks: [[mask.width, mask.height, 4, 0]]}}),
      masks: [values.buffer]};
  } finally {
    mask.close();
  }
}
// Copies each of the spec's masks into [buffers], naming it in the JSON as
// [width, height, bytes per value, index]: float32 confidences or uint8
// categories. The copies outlive the result, which frees Google's masks.
function copyMasks(result, buffers) {
  const named = {};
  for (const [field, depth] of Object.entries(spec.masks ?? {})) {
    const value = result[field];
    if (value == null) continue;
    const copy = mask => {
      const values = depth === 1 ? mask.getAsUint8Array() : mask.getAsFloat32Array();
      buffers.push(values.slice().buffer);
      return [mask.width, mask.height, depth, buffers.length - 1];
    };
    named[field] = Array.isArray(value) ? value.map(copy) : copy(value);
  }
  return named;
}
// Frees Google's masks: a segmenter result closes its own; in 1.0.1 the
// landmarker results have no close(), so their masks are closed one by one.
function closeMasks(result) {
  if (typeof result.close === 'function') return result.close();
  for (const field of Object.keys(spec.masks ?? {})) {
    const value = result[field];
    for (const mask of Array.isArray(value) ? value : value ? [value] : []) mask.close();
  }
}
// Image landmarks as x, y, z, visibility, presence per point (NaN when absent),
// transferred rather than serialized. Named landmarks stay in the JSON.
function pack(subjects) {
  if (subjects.some(points => points.some(point => point.name != null))) return null;
  const counts = subjects.map(points => points.length);
  const values = new Float64Array(counts.reduce((a, b) => a + b, 0) * 5);
  let at = 0;
  for (const points of subjects) {
    for (const point of points) {
      values[at++] = point.x;
      values[at++] = point.y;
      values[at++] = point.z;
      values[at++] = point.visibility ?? NaN;
      values[at++] = point.presence ?? NaN;
    }
  }
  return {counts, values};
}
// Several landmark fields in one buffer, one after another in [fields] order.
// Each entry of [parts] names a field and its points per subject, so the
// reader can slice the buffer apart.
function packParts(result, fields) {
  const subjects = [], parts = [];
  for (const field of fields) {
    const value = result[field] ?? [];
    parts.push([field, value.map(points => points.length)]);
    subjects.push(...value);
  }
  const packed = pack(subjects);
  return packed && {parts, values: packed.values};
}

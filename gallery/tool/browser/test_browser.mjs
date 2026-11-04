import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium, firefox, webkit} from 'playwright';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const argumentsMap = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split('=')));
const browserName = argumentsMap.browser || 'chromium';
const suite = argumentsMap.suite || 'all';
const delegate = argumentsMap.delegate === 'gpu' ? 'GPU' : 'CPU';
// The live demo the camera suite drives. The page publishes its probes and
// their mirror partners (AlignmentProbes in gallery/lib/live/live_subjects.dart):
// the official IMAGE task labels a face's landmarks by the side of the picture
// they appear on, so across a mirror it reports each probe's left/right
// partner, while a hand keeps its numbering (only its handedness flips).
const TASKS = {
  face: {tile: /Face Landmarker/, points: '478', fixture: 'web-camera.y4m',
    task: 'FaceLandmarker', model: 'face_landmarker.task', landmarks: 'faceLandmarks',
    options: {numFaces: 1}},
  hand: {tile: /Hand Landmarker/, points: '21', fixture: 'web-camera-hand.y4m',
    task: 'HandLandmarker', model: 'hand_landmarker.task', landmarks: 'landmarks',
    options: {numHands: 2}},
};
const taskName = argumentsMap.task || 'face';
const subject = TASKS[taskName];
assert.ok(subject, 'Unknown --task ' + taskName);
const base = argumentsMap['base-url'] || 'http://localhost:8866/flutter-mediapipe/';
// The gallery publishes its per-frame state for these checks only on request.
const gallery = base + (base.includes('?') ? '&' : '?') + 'test-hooks';
const apiBase = argumentsMap['api-url'] || 'http://localhost:8866/api-probe/';
const textAudioBase = argumentsMap['text-audio-url'] || 'http://localhost:8866/text-audio-probe/';
// Where the direct comparisons load Google's own JavaScript: jsDelivr, or with
// --official-runtime=<url> a copy `dart run mediapipe_core:web_runtime` wrote,
// so the comparisons do not depend on the CDN.
const officialRuntime = new URL(argumentsMap['official-runtime'] || 'https://cdn.jsdelivr.net/npm/', base).href;
const evidence = path.join(repo, 'build/ci-tmp/web-browser-' + browserName +
  (delegate === 'GPU' ? '-gpu' : '') + (taskName === 'face' ? '' : '-' + taskName) +
  (argumentsMap.runtime ? '-self-hosted' : ''));
fs.mkdirSync(evidence, {recursive: true});
const report = {browser: browserName, delegate, suite, task: taskName, checks: [], retries: [],
  physical_webcam_tested: false, software_webgl: browserName === 'chromium' && process.platform === 'linux'};
const logs = [];
const browsers = [];

// Google's model files by name, at the SHA-256 names `dart run
// mediapipe_core:bundle_models` gives them in the gallery's assets, and the
// root the direct comparisons load Google's JavaScript from.
const bundledModelsScript = runtime => {
  window.officialRuntime = runtime;
  let manifest;
  const key = async file => {
    manifest ??= fetch(new URL('assets/assets/mediapipe/manifest.json', document.baseURI)).then(r => r.json());
    const entry = (await manifest).models.find(m => m.url.endsWith('/' + file));
    if (!entry) throw new Error(file + ' is not bundled in this build');
    return 'assets/mediapipe/' + entry.file;
  };
  window.bundledModelKey = key;
  window.bundledModelUrl = async file => new URL('assets/' + await key(file), document.baseURI).href;
  // Google's official runtime for a family, at the version its package pins:
  // the bundle's exports and the loaded wasm fileset its tasks open with.
  window.officialTasks = async family => {
    const pin = await (await fetch(new URL(`assets/packages/mediapipe_${family}/assets/runtime.json`, document.baseURI))).json();
    const runtime = new URL(`${pin.package}@${pin.version}/`, window.officialRuntime);
    const bundle = await import(new URL(`${family}_bundle.mjs`, runtime).href);
    const files = await bundle.FilesetResolver[`for${family[0].toUpperCase()}${family.slice(1)}Tasks`](new URL('wasm', runtime).href);
    return {bundle, files};
  };
};

async function launch(deviceCount = 2, useFile = true) {
  const options = browserName === 'chromium' ? {
    // The lightweight headless shell rejects getUserMedia. Full Chromium's
    // modern headless mode exercises the same capture APIs as normal Chrome.
    channel: 'chromium',
    args: ['--use-fake-device-for-media-stream=device-count=' + deviceCount,
      ...(process.platform === 'linux' ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : []),
      ...(useFile ? ['--use-file-for-fake-video-capture=' + path.join(repo, 'build/ci-tmp', subject.fixture)] : [])],
  } : {
    // Hosted Linux has no GPU. Permit Mesa's software WebGL context for the
    // official CPU task's image upload/preprocessing (not GPU inference).
    firefoxUserPrefs: process.platform === 'linux' ? {'webgl.force-enabled': true} : {},
  };
  options.headless = argumentsMap.headed !== 'true';
  const browser = await ({chromium, firefox, webkit}[browserName]).launch(options);
  browsers.push(browser);
  report.browser_version = browser.version();
  return browser;
}

function observe(page) {
  page.on('crash', () => logs.push({type: 'crash', text: 'page crashed'}));
  page.on('console', msg => logs.push({type: msg.type(), text: msg.text()}));
  page.on('pageerror', error => logs.push({type: 'pageerror', text: error.stack}));
  page.on('response', response => {
    if (response.status() >= 400) logs.push({type: 'http', status: response.status(), url: response.url()});
  });
}

// [arg] is passed to [condition], which runs in the page.
async function wait(page, condition, arg = null, timeout = 60000) {
  await page.waitForFunction(condition, arg, {timeout});
}

// Same criterion as gallery/integration_test/support/alignment_oracle.dart:
// median probe deviation, and any single probe, as a fraction of the preview
// diagonal. tool/check_repository.py keeps the two pairs equal.
const alignmentTolerance = 0.015;
const alignmentOutlierTolerance = 0.03;
// The hand thumb tip is less stable between live VIDEO tracking and a fresh
// IMAGE pass over the screenshot; keep every other probe at the shared limit.
const handThumbTipOutlierTolerance = 0.05;

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

// Google's official IMAGE task, run in the page over PNG screenshot pixels.
async function detectScreenshot(page, png) {
  return page.evaluate(async ({base64, spec}) => {
    const {bundle, files} = await window.officialTasks('vision');
    const task = await bundle[spec.task].createFromOptions(files, {
      baseOptions: {delegate: 'CPU', modelAssetPath: await window.bundledModelUrl(spec.model)},
      runningMode: 'IMAGE', ...spec.options,
    });
    const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    const bitmap = await createImageBitmap(new Blob([bytes], {type: 'image/png'}));
    try {
      const found = task.detect(bitmap)[spec.landmarks];
      return {width: bitmap.width, height: bitmap.height, subjects: found.length,
        landmarks: found[0]?.map(p => [p.x, p.y]) ?? []};
    } finally {bitmap.close(); task.close();}
  }, {base64: png.toString('base64'), spec: {task: subject.task, model: subject.model,
    landmarks: subject.landmarks, options: subject.options}});
}

// The Dart overlay-alignment oracle, in the browser. Screenshot the preview
// with the overlay hidden, run the official IMAGE task over those pixels and
// compare the subject it finds with where the overlay draws the live result. The
// web view publishes the probes from the painter's own transform, relative to
// the overlay's box on the page; the screenshot is cropped to that box, so a
// video that is not under its overlay fails too. The mirrored hypothesis
// reflects each probe about the fitted frame's centre line, as the Dart
// oracle does, so a failure says which one the screen matches; each
// hypothesis reads the on-screen landmarks under the labels it implies.
async function alignmentCheck(page) {
  const overlay = () => page.locator('video').evaluate(video => ({
    subjects: video.getAttribute('data-subjects'),
    box: JSON.parse(video.getAttribute('data-overlay-box')),
    frame: JSON.parse(video.getAttribute('data-frame-box')),
    probes: JSON.parse(video.getAttribute('data-probes')),
    partners: JSON.parse(video.getAttribute('data-partners')),
    mirror: video.getAttribute('data-mirror') === 'true',
    rotation: Number(video.getAttribute('data-rotation')),
    video: (({x, y, width, height}) => [x, y, width, height])(video.getBoundingClientRect()),
    videoTransform: video.style.transform,
    dpr: window.devicePixelRatio,
  }));
  // The gallery has no overlay switch; `?test-hooks` installs this one.
  const showOverlay = show => page.evaluate(hide => window.__hideOverlay(hide), !show);
  const processed = () => Number(document.querySelector('video')?.getAttribute('data-processed-frames'));
  // A worker overlay's canvas reaches the screen on its own schedule, which on
  // a slow runner lags its drawing by more than a frame: with only the switch,
  // a capture taken after the worker drew a frame without the overlay could
  // still show an older frame with it. So its element is hidden too, a style
  // change the page's next frame shows.
  const showWorkerOverlays = shown => page.evaluate(visible => document
    .querySelectorAll('[data-worker-overlay]')
    .forEach(canvas => { canvas.style.visibility = visible ? '' : 'hidden'; }), shown);
  const hiddenAt = await page.evaluate(processed);
  await showOverlay(false);
  await showWorkerOverlays(false);
  // Flutter's painter, where the worker cannot draw, reads the switch when the
  // next result rebuilds the page; three results are enough for that.
  await wait(page, since => Number(document.querySelector('video')?.getAttribute('data-processed-frames')) >= since + 3,
    hiddenAt);
  // Keep the pointer, and any tooltip it raises, away from the preview.
  await page.mouse.move(1, page.viewportSize().height - 1);
  try {
    for (let attempt = 1; ; attempt++) {
      await wait(page, () => {
        const video = document.querySelector('video');
        return video?.getAttribute('data-subjects') === '1' && video.hasAttribute('data-probes');
      });
      // Two animation frames: Flutter has painted the hidden overlay.
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const before = await overlay();
      const x = Math.floor(before.box[0]), y = Math.floor(before.box[1]);
      const clip = {x, y, width: Math.ceil(before.box[0] + before.box[2]) - x,
        height: Math.ceil(before.box[1] + before.box[3]) - y};
      const png = await page.screenshot({clip});
      const after = await overlay();
      const observed = await detectScreenshot(page, png);
      // The fixture alternates subject and blank; retry a capture that met a blank.
      if ((after.subjects !== '1' || observed.subjects !== 1) && attempt < 5) continue;
      fs.writeFileSync(path.join(evidence, 'alignment-preview-without-overlay.png'), png);
      const measurement = {
        observed_subjects: observed.subjects,
        crop_size: [observed.width, observed.height],
        tolerance: alignmentTolerance,
        outlier_tolerance: alignmentOutlierTolerance,
        ...(taskName === 'hand' ? {thumb_tip_outlier_tolerance: handThumbTipOutlierTolerance} : {}),
        attempts: attempt,
        overlay_box_css: before.box,
        video_rect_css: before.video,
        frame_box_css: before.frame,
        device_pixel_ratio: before.dpr,
        frame_rotation: before.rotation,
        mirror: before.mirror,
        video_transform: before.videoTransform,
      };
      if (observed.subjects !== 1) return measurement;
      const {dpr} = before;
      const diagonal = Math.hypot(before.box[2], before.box[3]) * dpr;
      const axis = before.frame[0] + before.frame[2] / 2;
      const distance = (index, mirror, probeX, probeY) => {
        const [seenX, seenY] = observed.landmarks[mirror ? before.partners[index] : index];
        return Math.hypot((before.box[0] - clip.x + probeX) * dpr - seenX * observed.width,
          (before.box[1] - clip.y + probeY) * dpr - seenY * observed.height) / diagonal;
      };
      const distances = {}, mirrored = {};
      let drift = 0;
      for (const [index, [probeX, probeY]] of Object.entries(before.probes)) {
        assert.ok(index in before.partners, 'no mirror partner for probe ' + index);
        distances[index] = distance(index, before.mirror, probeX, probeY);
        mirrored[index] = distance(index, !before.mirror, 2 * axis - probeX, probeY);
        const [laterX, laterY] = after.probes?.[index] ?? [probeX, probeY];
        drift = Math.max(drift, Math.hypot(laterX - probeX, laterY - probeY));
      }
      Object.assign(measurement, {
        median: median(Object.values(distances)),
        maximum: Math.max(...Object.values(distances)),
        median_if_mirrored: median(Object.values(mirrored)),
        probe_drift_during_capture_css: drift,
        distances,
        distances_if_mirrored: mirrored,
      });
      measurement.aligned = measurement.median <= alignmentTolerance &&
        Object.entries(distances).every(([index, value]) => value <=
          (taskName === 'hand' && index === '4' ? handThumbTipOutlierTolerance : alignmentOutlierTolerance));
      return measurement;
    }
  } finally {
    await showWorkerOverlays(true);
    await showOverlay(true);
  }
}

async function apiChecks() {
  const browser = await launch();
  const page = await browser.newPage();
  await page.addInitScript(bundledModelsScript, officialRuntime);
  observe(page);
  await page.goto(apiBase + (delegate === 'GPU' ? '?delegate=gpu' : ''));
  // The probe runs every browser task. Hosted runners emulate WebGL in
  // software, so the GPU pass can take minutes there.
  await wait(page, () => window.mediapipeApiTestReport, null, 300000);
  const api = await page.evaluate(() => window.mediapipeApiTestReport);
  fs.writeFileSync(path.join(evidence, 'api-report.json'), JSON.stringify(api, null, 2));
  assert.equal(api.status, 'passed', JSON.stringify(api));
  const direct = await page.evaluate(async delegate => {
    const {bundle: {FaceLandmarker}, files} = await window.officialTasks('vision');
    const task = await FaceLandmarker.createFromOptions(files, {
      baseOptions: {delegate, modelAssetPath: await window.bundledModelUrl('face_landmarker.task')},
      runningMode: 'IMAGE', numFaces: 1, outputFaceBlendshapes: true, outputFacialTransformationMatrixes: true,
    });
    const response = await fetch(new URL('assets/assets/samples/portrait.jpg', document.baseURI));
    const bitmap = await createImageBitmap(await response.blob());
    try {
      const result = task.detect(bitmap);
      return {
        width: bitmap.width, height: bitmap.height,
        landmarks: result.faceLandmarks[0].map(p => [p.x, p.y, p.z]),
        blendshapes: result.faceBlendshapes[0].categories.map(c => c.score),
        matrix: result.facialTransformationMatrixes[0].data,
      };
    } finally {bitmap.close(); task.close();}
  }, delegate);
  fs.writeFileSync(path.join(evidence, 'official-js-reference.json'), JSON.stringify(direct, null, 2));
  assert.equal(api.image.width, direct.width);
  assert.equal(api.image.height, direct.height);
  const errors = {};
  for (const group of ['landmarks', 'blendshapes', 'matrix']) {
    const actual = api.image[group].flat();
    const expected = direct[group].flat();
    assert.equal(actual.length, expected.length);
    errors[group] = Math.max(...actual.map((value, i) => Math.abs(value - expected[i])));
    assert.ok(errors[group] < 1e-5, group + ' differs from official JavaScript: ' + errors[group]);
  }
  // Hand Landmarker through the Dart API versus Google's JavaScript on the
  // same image, runtime and delegate.
  const hand = await page.evaluate(async delegate => {
    const {bundle: {HandLandmarker}, files} = await window.officialTasks('vision');
    const task = await HandLandmarker.createFromOptions(files, {
      baseOptions: {delegate, modelAssetPath: await window.bundledModelUrl('hand_landmarker.task')},
      runningMode: 'IMAGE', numHands: 2,
    });
    const response = await fetch(new URL('assets/assets/samples/hands.jpg', document.baseURI));
    const bitmap = await createImageBitmap(await response.blob());
    try {
      const result = task.detect(bitmap);
      return {
        width: bitmap.width, height: bitmap.height,
        landmarks: result.landmarks.flatMap(points => points.map(p => [p.x, p.y, p.z])),
        world: result.worldLandmarks.flatMap(points => points.map(p => [p.x, p.y, p.z])),
        handedness: result.handedness.map(categories => categories[0].score),
      };
    } finally {bitmap.close(); task.close();}
  }, delegate);
  fs.writeFileSync(path.join(evidence, 'official-js-hand-reference.json'), JSON.stringify(hand, null, 2));
  assert.equal(api.hand.width, hand.width);
  assert.equal(api.hand.height, hand.height);
  const handErrors = {};
  for (const group of ['landmarks', 'world', 'handedness']) {
    const actual = api.hand[group].flat();
    const expected = hand[group].flat();
    assert.ok(expected.length > 0, 'official JavaScript found no hand');
    assert.equal(actual.length, expected.length, group + ' count differs from official JavaScript');
    handErrors[group] = Math.max(...actual.map((value, i) => Math.abs(value - expected[i])));
    assert.ok(handErrors[group] < 1e-5, 'hand ' + group + ' differs from official JavaScript: ' + handErrors[group]);
  }
  // Pose, Gesture and Holistic the same way: a fresh official task, run once
  // on the sample the Dart probe used. Holistic's IMAGE mode keeps state, so
  // only first calls are comparable.
  const landmarkTasks = await page.evaluate(async delegate => {
    const {bundle: vision, files} = await window.officialTasks('vision');
    const points = list => (list ?? []).map(p => [p.x, p.y, p.z]);
    const run = async (type, model, sample, options, method, parts) => {
      const task = await vision[type].createFromOptions(files, {
        baseOptions: {delegate, modelAssetPath: await window.bundledModelUrl(model)},
        runningMode: 'IMAGE', ...options,
      });
      const response = await fetch(new URL('assets/assets/samples/' + sample, document.baseURI));
      const bitmap = await createImageBitmap(await response.blob());
      try {
        const result = task[method](bitmap);
        return {width: bitmap.width, height: bitmap.height, parts: parts(result),
          gesture: result.gestures?.[0]?.[0]?.categoryName};
      } finally {bitmap.close(); task.close();}
    };
    return {
      pose: await run('PoseLandmarker', 'pose_landmarker_lite.task', 'pose.jpg', {}, 'detect', r => ({
        landmarks: points(r.landmarks[0]), world: points(r.worldLandmarks[0])})),
      gesture: await run('GestureRecognizer', 'gesture_recognizer.task', 'thumb_up.jpg', {numHands: 2}, 'recognize', r => ({
        landmarks: points(r.landmarks[0]), world: points(r.worldLandmarks[0]),
        gesture_score: [[r.gestures[0][0].score]]})),
      holistic: await run('HolisticLandmarker', 'holistic_landmarker.task', 'pose.jpg', {}, 'detect', r => ({
        pose: points(r.poseLandmarks[0]), pose_world: points(r.poseWorldLandmarks[0]),
        left_hand: points(r.leftHandLandmarks[0]), right_hand: points(r.rightHandLandmarks[0]),
        face: points(r.faceLandmarks[0])})),
    };
  }, delegate);
  fs.writeFileSync(path.join(evidence, 'official-js-landmark-tasks-reference.json'), JSON.stringify(landmarkTasks, null, 2));
  const landmarkTaskErrors = {};
  for (const [name, expected] of Object.entries(landmarkTasks)) {
    const actual = api.landmark_tasks[name];
    assert.equal(actual.width, expected.width, name);
    assert.equal(actual.height, expected.height, name);
    if (expected.gesture) assert.equal(actual.gesture, expected.gesture);
    landmarkTaskErrors[name] = {};
    for (const [part, values] of Object.entries(expected.parts)) {
      const got = actual.parts[part].flat();
      const want = values.flat();
      assert.equal(got.length, want.length, name + ' ' + part);
      const error = want.length ? Math.max(...got.map((value, i) => Math.abs(value - want[i]))) : 0;
      landmarkTaskErrors[name][part] = error;
      assert.ok(error < 1e-5, name + ' ' + part + ' differs from official JavaScript: ' + error);
    }
  }
  // Face Detector, Object Detector and Image Classifier the same way. Google's
  // boxes are float pixels; the Dart API truncates them, as its C API does.
  const detectionTasks = await page.evaluate(async delegate => {
    const {bundle: vision, files} = await window.officialTasks('vision');
    const response = await fetch(new URL('assets/assets/samples/portrait.jpg', document.baseURI));
    const bitmap = await createImageBitmap(await response.blob());
    const open = async (type, model, options) => vision[type].createFromOptions(files, {
      baseOptions: {delegate, modelAssetPath: await window.bundledModelUrl(model)},
      runningMode: 'IMAGE', ...options,
    });
    const boxes = detections => detections.map(d => {
      const b = d.boundingBox;
      return {box: [Math.trunc(b.originX), Math.trunc(b.originY), Math.trunc(b.originX + b.width),
        Math.trunc(b.originY + b.height)], score: d.categories[0].score,
        name: d.categories[0].categoryName || null, keypoints: d.keypoints.map(k => [k.x, k.y])};
    });
    const top = result => result.classifications[0].categories.map(c => ({score: c.score, name: c.categoryName}));
    // The category and the person (15) confidence at the centres of a 16 x 12
    // grid, as web_api_probe.dart samples them.
    const segmentation = (result, index = 15) => {
      const category = result.categoryMask;
      const classes = category.getAsUint8Array();
      const person = result.confidenceMasks[index].getAsFloat32Array();
      const values = [];
      for (let r = 0; r < 12; r++) {
        for (let c = 0; c < 16; c++) {
          const x = Math.floor((2 * c + 1) * category.width / 32);
          const y = Math.floor((2 * r + 1) * category.height / 24);
          values.push(classes[y * category.width + x], person[y * category.width + x]);
        }
      }
      result.close();
      return {values};
    };
    // A pose segmentation mask sampled on the same grid.
    const poseMask = (result, field) => {
      const mask = result[field][0];
      const data = mask.getAsFloat32Array();
      const values = [];
      for (let r = 0; r < 12; r++) {
        for (let c = 0; c < 16; c++) {
          values.push(data[Math.floor((2 * r + 1) * mask.height / 24) * mask.width
            + Math.floor((2 * c + 1) * mask.width / 32)]);
        }
      }
      // Landmarker results have no close() in 1.0.1; their masks do.
      result[field].forEach(m => m.close());
      return {values};
    };
    const figure = await createImageBitmap(await (await fetch(
      new URL('assets/assets/samples/pose.jpg', document.baseURI))).blob());
    try {
      const faces = await open('FaceDetector', 'blaze_face_short_range.tflite', {});
      const objects = await open('ObjectDetector', 'efficientdet_lite0.tflite', {maxResults: 5, scoreThreshold: 0.3});
      const classifier = await open('ImageClassifier', 'efficientnet_lite0.tflite', {maxResults: 3});
      const embedder = await open('ImageEmbedder', 'mobilenet_v3_small.tflite', {});
      const quantizer = await open('ImageEmbedder', 'mobilenet_v3_small.tflite',
        {l2Normalize: true, quantize: true});
      const segmenter = await open('ImageSegmenter', 'deeplab_v3.tflite',
        {outputConfidenceMasks: true, outputCategoryMask: true});
      const pose = await open('PoseLandmarker', 'pose_landmarker_lite.task',
        {outputSegmentationMasks: true});
      // Stateful MagicTouch runs on CPU only, in both delegate passes.
      const magic = await vision.InteractiveSegmenter.createFromOptions(files, {
        baseOptions: {delegate, modelAssetPath: await window.bundledModelUrl('interactive_segmentation.task')},
      });
      // A stroke history's mask, sampled on the same 16 x 12 grid. Each
      // stroke is [brush mode, [[x, y], ...], completed], multi-point since
      // WebGL draws nothing for a single point.
      const strokes = history => {
        const mask = magic.segment(history.map(([brushMode, points, isCompleted = true]) =>
          ({brushMode, isCompleted, point: points.map(([x, y]) => ({x, y}))})));
        try {
          const confidence = mask.getAsFloat32Array();
          const values = [];
          for (let r = 0; r < 12; r++) {
            for (let c = 0; c < 16; c++) {
              const x = Math.floor((2 * c + 1) * mask.width / 32);
              const y = Math.floor((2 * r + 1) * mask.height / 24);
              values.push(confidence[y * mask.width + x]);
            }
          }
          return {values};
        } finally {
          mask.close();
        }
      };
      const holistic = await open('HolisticLandmarker', 'holistic_landmarker.task',
        {outputPoseSegmentationMasks: true});
      try {
        return {
          face_detector: boxes(faces.detect(bitmap).detections),
          object_detector: boxes(objects.detect(bitmap).detections).map(({keypoints, ...rest}) => rest),
          image_classifier: top(classifier.classify(bitmap)),
          image_classifier_region: top(classifier.classify(bitmap,
            {regionOfInterest: {left: 0.25, top: 0.1, right: 0.75, bottom: 0.9}})),
          image_embedder: [{values: Array.from(embedder.embed(bitmap).embeddings[0].floatEmbedding)}],
          image_embedder_quantized: [{values: Array.from(quantizer.embed(bitmap).embeddings[0].quantizedEmbedding)}],
          image_segmenter: [segmentation(segmenter.segment(bitmap))],
          interactive_segmenter: (magic.setImage(bitmap), [
            strokes([[1, [[0.5, 0.4], [0.5, 0.45]]]]),
            strokes([[1, [[0.5, 0.4], [0.5, 0.45]]], [2, [[0.45, 0.8], [0.55, 0.8]]]]),
            strokes([[3, [[0.25, 0.1], [0.75, 0.1], [0.75, 0.9], [0.25, 0.9]]]]),
            strokes([[3, [[0.25, 0.1], [0.75, 0.9]]]]),
            strokes([[1, [[0.5, 0.4], [0.5, 0.45]], false]]),
          ]),
          pose_mask: [poseMask(pose.detect(figure), 'segmentationMasks')],
          holistic_mask: [poseMask(holistic.detect(figure), 'poseSegmentationMasks')],
        };
      } finally {
        faces.close(); objects.close(); classifier.close(); embedder.close(); quantizer.close();
        segmenter.close(); magic.close(); pose.close(); holistic.close();
      }
    } finally {bitmap.close(); figure.close();}
  }, delegate);
  fs.writeFileSync(path.join(evidence, 'official-js-detection-tasks-reference.json'), JSON.stringify(detectionTasks, null, 2));
  const detectionErrors = {};
  for (const [name, expected] of Object.entries(detectionTasks)) {
    const actual = api.detection_tasks[name];
    assert.equal(actual.length, expected.length, name);
    let error = 0;
    expected.forEach((want, i) => {
      const got = actual[i];
      assert.equal(got.name, want.name, name);
      if (want.box) assert.deepEqual(got.box, want.box, name);
      if (want.values) {
        assert.equal(got.values.length, want.values.length, name);
        want.values.forEach((value, j) => { error = Math.max(error, Math.abs(got.values[j] - value)); });
        return;
      }
      error = Math.max(error, Math.abs(got.score - want.score));
      (want.keypoints ?? []).forEach((point, j) => point.forEach((value, k) => {
        error = Math.max(error, Math.abs(got.keypoints[j][k] - value));
      }));
    });
    detectionErrors[name] = error;
    assert.ok(error < 1e-5, name + ' differs from official JavaScript: ' + error);
  }
  report.official_js_detection_tasks_maximum_absolute_error = detectionErrors;
  // Google reads a lasso as the box around its points on this delegate too:
  // the rectangle's outline and its two opposite corners give one mask.
  {
    const [, , outline, corners] = detectionTasks.interactive_segmenter;
    let error = 0;
    outline.values.forEach((value, i) => { error = Math.max(error, Math.abs(value - corners.values[i])); });
    assert.ok(error < 1e-5, 'lasso outline and corners differ in official JavaScript: ' + error);
    report.official_js_lasso_box_maximum_absolute_error = error;
  }
  assert.deepEqual(await page.evaluate(() => mediapipeVision.stats().activeWorkers), 0);
  report.official_js_maximum_absolute_error = errors;
  report.official_js_hand_maximum_absolute_error = handErrors;
  report.official_js_landmark_tasks_maximum_absolute_error = landmarkTaskErrors;
  report.checks.push(...api.checks, 'same-browser-official-js-reference', 'same-browser-official-js-hand-reference',
    'same-browser-official-js-pose-gesture-holistic-reference',
    'same-browser-official-js-detection-classification-reference');
  await page.screenshot({path: path.join(evidence, 'api.png')});
  await browser.close();
}

async function iosUserAgentCpuCheck() {
  const userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/133.0 Mobile/15E148 Safari/605.1.15';
  const browser = await launch();
  const context = await browser.newContext({userAgent});
  const page = await context.newPage();
  await page.addInitScript(bundledModelsScript, officialRuntime);
  observe(page);
  // Failed creation terminates the worker before Playwright can inspect it.
  // Hold only the create request, then release it unchanged after observation.
  await page.addInitScript(() => {
    const postMessage = Worker.prototype.postMessage;
    const pending = [];
    Worker.prototype.postMessage = function(...args) {
      if (args[0]?.type === 'create') pending.push([this, args]);
      else postMessage.apply(this, args);
    };
    window.testResumeTaskCreation = () => {
      Worker.prototype.postMessage = postMessage;
      for (const [worker, args] of pending) postMessage.apply(worker, args);
    };
  });
  const result = report.ios_user_agent_cpu = {
    override_method: 'browser-context',
    requested_user_agent: userAgent,
    physical_ios_tested: false,
  };
  // Inspect the actual module worker used by the Dart API, not just the page.
  const workerState = page.waitForEvent('worker', {
    predicate: worker => worker.url().endsWith('/mediapipe_vision/assets/worker.js'),
  }).then(worker => worker.evaluate(() => ({
    user_agent: navigator.userAgent,
    document_type: typeof document,
    offscreen_canvas_type: typeof OffscreenCanvas,
  })));
  try {
    await page.goto(apiBase);
    result.worker = await workerState;
    assert.equal(result.worker.user_agent, userAgent, 'iOS Firefox UA must reach the task worker');
    assert.equal(result.worker.document_type, 'undefined');
    assert.equal(result.worker.offscreen_canvas_type, 'function');
    await page.evaluate(() => window.testResumeTaskCreation());
    await wait(page, () => window.mediapipeApiTestReport);
    result.api = await page.evaluate(() => window.mediapipeApiTestReport);
    assert.equal(result.api.status, 'passed',
      'iOS Firefox UA CPU task must construct and run: ' + (result.api.error || JSON.stringify(result.api)));
    assert.equal(await page.evaluate(() => mediapipeVision.stats().activeWorkers), 0);
    report.checks.push('ios-firefox-user-agent-cpu-worker-construction-and-inference');
  } finally {
    fs.writeFileSync(path.join(evidence, 'ios-user-agent-cpu.json'), JSON.stringify(result, null, 2));
    await context.close();
    await browser.close();
  }
}

async function installCaptureObservations(page, emulateMobileFacing = false) {
  await page.addInitScript(emulateFacing => {
    window.testCaptureTracks = [];
    window.testFrameCallbacks = new Set();
    window.testWorkers = [];
    window.testCaptureDiagnostics = [];
    const NativeWorker = window.Worker;
    window.Worker = class extends NativeWorker {
      constructor(...args) {super(...args); window.testWorkers.push(this);}
      // The bridge preloads a spare worker for the next task; its create
      // message makes it that task's worker.
      postMessage(message, ...rest) {
        if (message?.type === 'preload') this.testSpare = true;
        if (message?.type === 'create') this.testSpare = false;
        return super.postMessage(message, ...rest);
      }
    };
    const getUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    navigator.mediaDevices.getUserMedia = async constraints => {
      let stream;
      try {
        let requested = constraints;
        const facing = constraints.video?.facingMode;
        const direction = typeof facing === 'string' ? facing : facing?.exact ?? facing?.ideal;
        if (emulateFacing && direction) {
          const devices = (await navigator.mediaDevices.enumerateDevices()).filter(d => d.kind === 'videoinput');
          const target = direction === 'environment' ? devices[1] ?? devices[0] : devices[0];
          requested = {...constraints, video: {...constraints.video, facingMode: undefined,
            deviceId: {exact: target.deviceId}}};
        }
        stream = await getUserMedia(requested);
        if (emulateFacing && window.testCaptureTracks.length > 0) {
          // Let Flutter rebuild while the previous stream is released. A slow
          // mobile flip must keep the video element mounted until play().
          await new Promise(resolve => setTimeout(resolve, 250));
        }
        window.testCaptureDiagnostics.push({stage: 'getUserMedia', status: 'passed', constraints,
          settings: stream.getVideoTracks().map(t => t.getSettings())});
      } catch (error) {
        window.testCaptureDiagnostics.push({stage: 'getUserMedia', status: 'failed', name:error.name, message:error.message});
        throw error;
      }
      window.testCaptureTracks.push(...stream.getTracks());
      return stream;
    };
    const prototype = HTMLVideoElement.prototype;
    const play = prototype.play;
    prototype.play = async function(...args) {
      try {return await play.apply(this,args);}
      catch(error) {
        window.testCaptureDiagnostics.push({stage:'video.play',status:'failed',name:error.name,message:error.message});
        throw error;
      }
    };
    if (prototype.requestVideoFrameCallback) {
      const request = prototype.requestVideoFrameCallback;
      const cancel = prototype.cancelVideoFrameCallback;
      prototype.requestVideoFrameCallback = function(callback) {
        const id = request.call(this, (now, metadata) => {
          window.testFrameCallbacks.delete(id);
          callback(now, metadata);
        });
        window.testFrameCallbacks.add(id);
        return id;
      };
      prototype.cancelVideoFrameCallback = function(id) {
        window.testFrameCallbacks.delete(id);
        return cancel.call(this, id);
      };
    }
  }, emulateMobileFacing);
}

async function cameraChecks() {
  assert.equal(browserName, 'chromium', 'The Y4M webcam fixture uses Chromium flags.');
  const browser = await launch();
  const context = await browser.newContext({viewport: {width: 1280, height: 720}});
  await context.grantPermissions(['camera'], {origin: new URL(base).origin});
  const page = await context.newPage();
  await page.addInitScript(bundledModelsScript, officialRuntime);
  observe(page);
  await installCaptureObservations(page);
  await page.goto(gallery);
  await page.getByRole('button', {name: subject.tile}).click();
  // The gallery opens on GPU where offered; the expected points are the
  // chosen delegate's, so select it rather than rely on the default.
  await page.getByRole('button', {name: delegate, exact: true}).click({timeout: 120000});
  await wait(page, points => {
    const video = document.querySelector('video');
    return Number(video?.getAttribute('data-processed-frames')) >= 12 &&
      video?.getAttribute('data-landmarks') === points;
  }, subject.points);
  report.camera = await page.locator('video').evaluate(video => ({
    width: video.videoWidth, height: video.videoHeight,
    timestamp: Number(video.getAttribute('data-timestamp')),
    frames: Number(video.getAttribute('data-processed-frames')),
    mirror: video.style.transform,
  }));
  assert.equal(report.camera.width, 640);
  assert.equal(report.camera.height, 480);
  assert.equal(report.camera.mirror, 'scaleX(-1)');
  await page.screenshot({path: path.join(evidence, 'camera-' + taskName + '.png')});
  const alignment = report.alignment = await alignmentCheck(page);
  const verdict = `median ${alignment.median?.toFixed(4)}, max ${alignment.maximum?.toFixed(4)}; ` +
    `the mirrored hypothesis scores ${alignment.median_if_mirrored?.toFixed(4)}`;
  assert.equal(alignment.observed_subjects, 1, 'the on-screen preview must show one ' + taskName);
  assert.ok(alignment.median <= alignmentTolerance, 'overlay is off the on-screen ' + taskName + ': ' + verdict);
  assert.ok(alignment.aligned, 'one probe is far off the on-screen ' + taskName + ': ' + verdict);
  report.checks.push('overlay-alignment-oracle-on-screen-pixels');
  await wait(page, () => document.querySelector('video')?.getAttribute('data-subjects') === '0');
  await wait(page, points => document.querySelector('video')?.getAttribute('data-landmarks') === points, subject.points);
  assert.ok(await page.locator('video').evaluate(v => Number(v.getAttribute('data-timestamp'))) > report.camera.timestamp);
  report.checks.push('real-getusermedia-y4m-' + taskName + '-blank-recovery-timestamps');

  const tracksBeforeResize = await page.evaluate(() => {
    window.testPreviewVideo = document.querySelector('video');
    return window.testCaptureTracks.length;
  });
  for (const viewport of [{width: 390, height: 844}, {width: 1440, height: 900}]) {
    await page.setViewportSize(viewport);
    await page.waitForFunction(() => {
      const rect = document.querySelector('video')?.getBoundingClientRect();
      return rect && Math.abs(rect.width / rect.height - 4 / 3) < 0.01;
    });
    await page.waitForTimeout(300);
    assert.ok(await page.evaluate(() => document.querySelector('video') === window.testPreviewVideo),
      'responsive layout replaced the live video element');
    assert.equal(await page.evaluate(() => window.testCaptureTracks.length), tracksBeforeResize,
      'responsive layout recaptured the camera');
    await page.screenshot({path: path.join(evidence, 'camera-' + viewport.width + '.png')});
  }
  report.checks.push('portrait-and-landscape-preview-aspect-ratio');
  // Switch the actual running gallery task, ensuring the requested delegate
  // completes inference and releases its worker before switching back.
  const tracksBeforeDelegateSwitch = await page.evaluate(() => window.testCaptureTracks.length);
  await page.getByRole('button', {name: 'GPU', exact: true}).click({timeout: 30000});
  await wait(page, points => document.querySelector('video')?.getAttribute('data-delegate') === 'gpu' &&
    document.querySelector('video')?.getAttribute('data-landmarks') === points, subject.points);
  const afterGpuTracks = await page.evaluate(() => window.testCaptureTracks.length);
  assert.equal(afterGpuTracks, tracksBeforeDelegateSwitch,
    'GPU switch recaptured the camera: ' + JSON.stringify(await page.evaluate(() => ({
      capture: window.testCaptureDiagnostics,
      body: document.body.innerText.slice(0, 1000),
    }))));
  await page.screenshot({path: path.join(evidence, 'camera-gpu-' + taskName + '.png')});
  await page.getByRole('button', {name: 'CPU', exact: true}).click({timeout: 30000});
  await wait(page, points => document.querySelector('video')?.getAttribute('data-delegate') === 'cpu' &&
    document.querySelector('video')?.getAttribute('data-landmarks') === points, subject.points);
  assert.equal(await page.evaluate(() => mediapipeVision.stats().activeWorkers), 1);
  assert.ok(await page.evaluate(expected => window.testCaptureTracks.length === expected &&
    window.testCaptureTracks.at(-1).readyState === 'live', tracksBeforeDelegateSwitch),
  'changing delegate must keep the current camera stream');
  report.checks.push('live-cpu-gpu-cpu-switch-' + taskName + '-inference-worker-cleanup');
  await page.getByText('Home', {exact: true}).click();
  await wait(page, () => mediapipeVision.stats().activeWorkers === 0 &&
    window.testCaptureTracks.every(t => t.readyState === 'ended') &&
    window.testFrameCallbacks.size === 0);
  await page.getByRole('button', {name: subject.tile}).click();
  await wait(page, points => document.querySelector('video')?.getAttribute('data-landmarks') === points, subject.points);
  await page.getByText('Home', {exact: true}).click();
  await wait(page, () => mediapipeVision.stats().activeWorkers === 0 &&
    mediapipeVision.stats().pendingRequests === 0 &&
    window.testCaptureTracks.every(t => t.readyState === 'ended') &&
    window.testFrameCallbacks.size === 0);
  report.checks.push('automatic-start-navigation-tracks-workers-callback-cleanup');
  await context.close();
  // The checks below exercise the shared controller's lifecycle (permissions,
  // device switching, worker failure), which does not depend on the task.
  // They run once, with face.
  if (taskName !== 'face') {
    await browser.close();
    return;
  }

  const denied = await browser.newContext();
  await denied.grantPermissions([], {origin: new URL(base).origin});
  const deniedPage = await denied.newPage();
  await deniedPage.addInitScript(bundledModelsScript, officialRuntime);
  observe(deniedPage);
  await deniedPage.goto(gallery);
  await deniedPage.getByRole('button', {name: /Face Landmarker/}).click();
  await deniedPage.getByText(/Camera permission denied/).waitFor();
  await wait(deniedPage, () => mediapipeVision.stats().activeWorkers === 0);
  await deniedPage.screenshot({path: path.join(evidence, 'permission-denied.png')});
  report.checks.push('browser-permission-denied-and-worker-cleanup');
  await denied.close();
  await browser.close();

  // File-backed Chrome capture exposes one device. Use Chrome's built-in
  // pattern cameras for native enumeration/device-selection coverage.
  const multiple = await launch(2, false);
  const multipleContext = await multiple.newContext({
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/153.0 Mobile/15E148 Safari/604.1',
  });
  await multipleContext.grantPermissions(['camera'], {origin: new URL(base).origin});
  const multiplePage = await multipleContext.newPage();
  await multiplePage.addInitScript(bundledModelsScript, officialRuntime);
  observe(multiplePage);
  await installCaptureObservations(multiplePage, true);
  await multiplePage.goto(gallery);
  await multiplePage.getByRole('button', {name: /Face Landmarker/}).click();
  await wait(multiplePage, () => Number(document.querySelector('video')?.getAttribute('data-processed-frames')) >= 12);
  assert.ok(await multiplePage.evaluate(() => {
    const video = document.querySelector('video');
    const canvas = video?.parentElement?.querySelector('canvas');
    if (!video || !canvas) return false;
    const videoRect = video.getBoundingClientRect();
    const canvasRect = canvas.getBoundingClientRect();
    const pixel = canvas.getContext('2d').getImageData(
      Math.floor(canvas.width / 2), Math.floor(canvas.height / 2), 1, 1,
    ).data;
    return canvas.width === video.videoWidth &&
      canvas.height === video.videoHeight &&
      canvas.style.transform === video.style.transform &&
      Math.abs(canvasRect.width - videoRect.width) < 1 &&
      Math.abs(canvasRect.height - videoRect.height) < 1 &&
      pixel[3] === 255;
  }), 'the iOS preview canvas must show the same full frame used for detection');
  report.checks.push('ios-canvas-preview-matches-detected-frame');
  const workersBeforeCameraFlip = await multiplePage.evaluate(() => mediapipeVision.stats().totalCreated);
  const firstDevice = await multiplePage.evaluate(() => window.testCaptureTracks.at(-1).getSettings().deviceId);
  await multiplePage.getByRole('button', {name: 'Switch to back camera'}).click();
  await wait(multiplePage, () => Number(document.querySelector('video')?.getAttribute('data-processed-frames')) >= 12 &&
    document.querySelector('video')?.style.transform === '');
  const secondDevice = await multiplePage.evaluate(() => window.testCaptureTracks.at(-1).getSettings().deviceId);
  assert.notEqual(firstDevice, secondDevice);
  assert.ok(await multiplePage.evaluate(() => window.testCaptureTracks.some(t => t.readyState === 'ended')));
  await multiplePage.getByRole('button', {name: 'Switch to front camera'}).click();
  try {
    await wait(multiplePage, () => Number(document.querySelector('video')?.getAttribute('data-processed-frames')) >= 12 &&
      document.querySelector('video')?.style.transform === 'scaleX(-1)');
  } catch (error) {
    const state = await multiplePage.evaluate(() => {
      const video = document.querySelector('video');
      return {
        video: video && {
          width: video.videoWidth,
          height: video.videoHeight,
          readyState: video.readyState,
          frames: video.getAttribute('data-processed-frames'),
          mirror: video.style.transform,
          srcObject: Boolean(video.srcObject),
        },
        tracks: window.testCaptureTracks.map(track => ({
          readyState: track.readyState,
          settings: track.getSettings(),
        })),
        capture: window.testCaptureDiagnostics,
        workers: mediapipeVision.stats(),
        body: document.body.innerText.slice(0, 1000),
      };
    });
    fs.writeFileSync(path.join(evidence, 'front-flip-timeout.json'), JSON.stringify(state, null, 2));
    throw new Error('front camera did not resume after flip: ' + JSON.stringify(state), {cause: error});
  }
  const thirdDevice = await multiplePage.evaluate(() => window.testCaptureTracks.at(-1).getSettings().deviceId);
  assert.equal(thirdDevice, firstDevice);
  assert.equal(await multiplePage.evaluate(() => mediapipeVision.stats().totalCreated), workersBeforeCameraFlip,
    'flipping the camera must keep the existing task worker');
  await multiplePage.getByText('Home', {exact: true}).click();
  await wait(multiplePage, () => mediapipeVision.stats().activeWorkers === 0 &&
    window.testCaptureTracks.every(t => t.readyState === 'ended'));
  report.checks.push('mobile-browser-front-back-front-switch-and-mirroring');
  // Trigger the actual worker error handler while gallery capture is active.
  await multiplePage.getByRole('button', {name: /Face Landmarker/}).click();
  await wait(multiplePage, () => Number(document.querySelector('video')?.getAttribute('data-processed-frames')) >= 3);
  await multiplePage.waitForFunction(() => {
    if (mediapipeVision.stats().pendingRequests === 0) return false;
    // The task's worker, not a spare the bridge may have spawned since.
    window.testWorkers.filter(worker => !worker.testSpare).at(-1)
      .dispatchEvent(new ErrorEvent('error', {message: 'Injected worker failure'}));
    return true;
  }, null, {polling: 1});
  await multiplePage.getByText(/Injected worker failure/).waitFor();
  await wait(multiplePage, () => mediapipeVision.stats().activeWorkers === 0 &&
    window.testCaptureTracks.every(t => t.readyState === 'ended'));
  report.checks.push('worker-error-rejects-pending-requests-and-releases-capture');
  await multiplePage.getByText('Home', {exact: true}).click();
  await multiplePage.getByRole('button', {name: /Face Landmarker/}).click();
  await wait(multiplePage, () => Number(document.querySelector('video')?.getAttribute('data-processed-frames')) >= 3);
  await multiplePage.evaluate(() => {
    window.testCaptureTracks.find(t => t.readyState === 'live').dispatchEvent(new Event('ended'));
  });
  await multiplePage.getByText(/Camera disconnected/).waitFor();
  await wait(multiplePage, () => mediapipeVision.stats().activeWorkers === 0 &&
    window.testCaptureTracks.every(t => t.readyState === 'ended'));
  report.checks.push('worker-error-reopen-and-simulated-track-ended-cleanup');
  await multiple.close();

  const missing = await launch(0, false);
  const missingContext = await missing.newContext();
  await missingContext.grantPermissions(['camera'], {origin: new URL(base).origin});
  const missingPage = await missingContext.newPage();
  await missingPage.addInitScript(bundledModelsScript, officialRuntime);
  observe(missingPage);
  await missingPage.goto(gallery);
  await missingPage.getByRole('button', {name: /Face Landmarker/}).click();
  await missingPage.getByText(/No camera found/).waitFor();
  await wait(missingPage, () => mediapipeVision.stats().activeWorkers === 0);
  report.checks.push('browser-no-video-device-and-worker-cleanup');
  await missing.close();
}

// Text Classifier, Text Embedder, Language Detector and Audio Classifier
// through the Dart API, against Google's JavaScript on the same page, runtime
// and inputs, the audio stream included; in Chromium also two seconds of
// microphone input fed from a speech clip by Chrome's fake capture.
async function textAudioChecks() {
  const microphone = browserName === 'chromium';
  const browser = await ({chromium, firefox, webkit}[browserName]).launch({
    headless: argumentsMap.headed !== 'true',
    ...(microphone ? {channel: 'chromium', args: ['--use-fake-device-for-media-stream',
      '--use-file-for-fake-audio-capture=' + path.join(repo, 'gallery/assets/samples/speech_16000_hz_mono.wav')]} : {}),
  });
  browsers.push(browser);
  report.browser_version = browser.version();
  const context = await browser.newContext(microphone ? {permissions: ['microphone']} : {});
  const page = await context.newPage();
  await page.addInitScript(bundledModelsScript, officialRuntime);
  observe(page);
  // Where the package's workers load Google's runtimes from: jsDelivr, or with
  // --runtime=<url> a root the probe's bundle serves (MediaPipeWebRuntime).
  const runtimeRoot = new URL(argumentsMap.runtime || 'https://cdn.jsdelivr.net/npm/', textAudioBase).href;
  const runtimeRequests = [];
  const recordRuntime = request => {
    if (/@mediapipe\/tasks-(text|audio)@/.test(request.url())) runtimeRequests.push(request.url());
  };
  context.on('request', recordRuntime);
  const query = new URLSearchParams();
  if (microphone) query.set('mic', '1');
  if (argumentsMap.runtime) query.set('runtime', argumentsMap.runtime);
  await page.goto(textAudioBase + (query.size ? '?' + query : ''));
  await wait(page, () => window.mediapipeTextAudioReport, null, 300000);
  context.off('request', recordRuntime);
  const api = await page.evaluate(() => window.mediapipeTextAudioReport);
  fs.writeFileSync(path.join(evidence, 'text-audio-runtime-requests.json'), JSON.stringify(runtimeRequests, null, 2));
  for (const family of ['text', 'audio']) {
    assert.ok(runtimeRequests.some(url => url.startsWith(runtimeRoot + `@mediapipe/tasks-${family}@`)),
      `no ${family} runtime request under ${runtimeRoot}: ${runtimeRequests}`);
  }
  assert.deepEqual(runtimeRequests.filter(url => !url.startsWith(runtimeRoot)), [],
    'runtime requests outside ' + runtimeRoot);
  report.runtime_root = runtimeRoot;
  report.checks.push('text-audio-runtime-from-configured-root');
  assert.equal(api.model_cache, 'passed');
  report.checks.push('web-model-cache-offline-hit');
  if (argumentsMap.runtime && browserName === 'chromium') {
    // The same pinned SHA-384 must reject a changed file from a self-hosted root.
    const tampered = await context.newPage();
    await tampered.addInitScript(bundledModelsScript, officialRuntime);
    await tampered.route('**/text_bundle.mjs', route =>
      route.fulfill({status: 200, contentType: 'text/javascript', body: 'tampered'}));
    await tampered.goto(textAudioBase + '?runtime=' + encodeURIComponent(argumentsMap.runtime));
    await wait(tampered, () => window.mediapipeTextAudioReport, null, 30000);
    const failure = await tampered.evaluate(() => window.mediapipeTextAudioReport);
    assert.equal(failure.status, 'failed');
    assert.match(failure.error, /text_bundle\.mjs: SHA-384 mismatch/);
    report.checks.push('tampered-self-hosted-runtime-rejected');
    await tampered.close();
  }
  fs.writeFileSync(path.join(evidence, 'text-audio-report.json'), JSON.stringify(api, null, 2));
  assert.equal(api.status, 'passed', JSON.stringify(api));
  const official = await page.evaluate(async () => {
    const asset = name => new URL('assets/' + name, document.baseURI).href;
    const bytes = async name => new Uint8Array(await (await fetch(asset(name))).arrayBuffer());
    const {bundle: text, files: textFiles} = await window.officialTasks('text');
    const heads = result => result.classifications.map(h => h.categories.map(c =>
      [c.index, c.score, c.categoryName || null, c.displayName || null]));
    // The package sends an unset score threshold as 0, as Google's Python and
    // C APIs do (mediapipe_text's default in lib/src/types/options.dart), so
    // the reference passes it too.
    const classifier = [];
    for (const [input, options] of [['Hello, world!', {}],
        ['This was a terrible movie. I hated every minute.', {}],
        ['Hello, world!', {maxResults: 1}], ['Hello, world!', {categoryDenylist: ['positive']}]]) {
      const task = await text.TextClassifier.createFromOptions(textFiles,
        {scoreThreshold: 0, ...options, baseOptions: {modelAssetBuffer: await bytes(await window.bundledModelKey('bert_classifier.tflite'))}});
      classifier.push(heads(task.classify(input)));
      task.close();
    }
    const embedder = {};
    for (const quantize of [false, true]) {
      const task = await text.TextEmbedder.createFromOptions(textFiles, {l2Normalize: quantize, quantize,
        baseOptions: {modelAssetBuffer: await bytes(await window.bundledModelKey('universal_sentence_encoder.tflite'))}});
      const e = ['Hello, world!', 'Hello there!', 'The spacecraft landed on Mars.'].map(t => task.embed(t).embeddings[0]);
      embedder[quantize ? 'quantized' : 'float'] = {
        values: e.map(v => Array.from(quantize ? v.quantizedEmbedding : v.floatEmbedding)),
        head: [e[0].headIndex, e[0].headName || null],
        similarity: [text.TextEmbedder.cosineSimilarity(e[0], e[1]), text.TextEmbedder.cosineSimilarity(e[0], e[2])],
      };
      task.close();
    }
    // EmbeddingGemma, when bundled: Google's embedder with its TextFormatOptions,
    // the same cases as the probe's embeddingGemmaCases.
    const manifest = await (await fetch(asset('assets/manifest.json'))).json();
    let embeddingGemma = 'not bundled';
    if (manifest.tasks.includes('embedding_gemma')) {
      const cases = [
        ['A cat is sleeping on the sofa.', undefined],
        ['A cat is sleeping on the sofa.', {type: 'SEMANTIC_SIMILARITY', textRole: 'QUERY'}],
        ['How do I grow tomatoes?', {type: 'RETRIEVAL_QUERY', textRole: 'QUERY'}],
        ['Plant tomatoes in a sunny spot and water regularly.',
          {type: 'RETRIEVAL_DOCUMENT', title: 'Growing tomatoes', textRole: 'DOCUMENT'}],
        ['Sort a list of integers.', {type: 'CODE_RETRIEVAL', textRole: 'QUERY'}],
      ];
      embeddingGemma = {};
      const gemma = await bytes(await window.bundledModelKey('embedding_gemma.task'));
      for (const quantize of [false, true]) {
        const task = await text.TextEmbedder.createFromOptions(textFiles, {l2Normalize: quantize, quantize,
          baseOptions: {modelAssetBuffer: gemma}});
        const e = (quantize ? cases.slice(0, 2) : cases).map(([t, options]) => task.embed(t, options).embeddings[0]);
        embeddingGemma[quantize ? 'quantized' : 'float'] = {
          values: e.map(v => Array.from(quantize ? v.quantizedEmbedding : v.floatEmbedding)),
          head: [e[0].headIndex, e[0].headName || null],
          similarity: quantize ? null : [text.TextEmbedder.cosineSimilarity(e[0], e[1]), text.TextEmbedder.cosineSimilarity(e[2], e[3])],
        };
        task.close();
      }
    }
    const detector = await text.LanguageDetector.createFromOptions(textFiles,
      {maxResults: 3, scoreThreshold: 0, baseOptions: {modelAssetBuffer: await bytes(await window.bundledModelKey('language_detector.tflite'))}});
    const language = ['Hello, world!', 'Quiero agua, por favor.', 'こんにちは、元気ですか？'].map(t =>
      detector.detect(t).languages.map(l => [l.languageCode, l.probability]));
    detector.close();
    const {bundle: audio, files: audioFiles} = await window.officialTasks('audio');
    const yamnet = await audio.AudioClassifier.createFromOptions(audioFiles,
      {baseOptions: {modelAssetBuffer: await bytes(await window.bundledModelKey('yamnet.tflite'))}});
    const clips = {};
    const decoded = {};
    const chunks = result => result.map(chunk => [chunk.timestampMs ?? 0,
      chunk.classifications[0].categories.slice(0, 5).map(c => [c.index, c.score, c.categoryName || null])]);
    for (const clip of ['speech_16000_hz_mono.wav', 'speech_48000_hz_mono.wav']) {
      // Google's sample clips are 16-bit PCM mono.
      const wav = new DataView((await bytes('assets/samples/' + clip)).buffer);
      let at = 12, rate = 0, samples;
      while (at + 8 <= wav.byteLength) {
        const tag = String.fromCharCode(...[0, 1, 2, 3].map(i => wav.getUint8(at + i)));
        const size = wav.getUint32(at + 4, true);
        if (tag === 'fmt ') rate = wav.getUint32(at + 12, true);
        if (tag === 'data') samples = Float32Array.from({length: size >> 1}, (_, i) => wav.getInt16(at + 8 + 2 * i, true) / 32768);
        at += 8 + size + (size & 1);
      }
      decoded[clip] = samples;
      clips[clip] = chunks(yamnet.classify(samples, rate));
    }
    // Google's answers for the Dart stream, which browsers run emulated on
    // clips mode: each 48 kHz window's span of 46,800 frames as a clip, its
    // first chunk, and the lone half second.
    const speech48 = decoded['speech_48000_hz_mono.wav'];
    const spans = [];
    for (let start = 0; start < speech48.length; start += 46800) {
      spans.push(chunks(yamnet.classify(speech48.subarray(start, start + 46800), 48000))[0]);
    }
    const lone = chunks(yamnet.classify(decoded['speech_16000_hz_mono.wav'].subarray(0, 8000), 16000));
    yamnet.close();
    return {classifier, embedder, embedding_gemma: embeddingGemma, language, audio: clips,
      stream: {spans, lone}};
  });
  fs.writeFileSync(path.join(evidence, 'text-audio-official.json'), JSON.stringify(official, null, 2));
  // Same runtime and inputs: every number must match, strings exactly.
  const errors = {};
  const compare = (group, actual, expected, where = group) => {
    if (typeof expected === 'number') {
      assert.equal(typeof actual, 'number', where);
      errors[group] = Math.max(errors[group] ?? 0, Math.abs(actual - expected));
      assert.ok(Math.abs(actual - expected) < 1e-5, where + ': ' + actual + ' vs ' + expected);
    } else if (Array.isArray(expected)) {
      assert.equal(actual.length, expected.length, where + ' length');
      expected.forEach((value, i) => compare(group, actual[i], value, where + '[' + i + ']'));
    } else if (expected && typeof expected === 'object') {
      for (const key of Object.keys(expected)) compare(group, actual[key], expected[key], where + '.' + key);
    } else {
      assert.equal(actual, expected, where);
    }
  };
  for (const group of ['classifier', 'embedder', 'language', 'audio']) compare(group, api[group], official[group]);
  report.text_audio_max_error = errors;
  report.checks.push('text-audio-match-official-javascript');
  if (official.embedding_gemma !== 'not bundled') {
    // Google's JavaScript formats the prompts; the package must hand it the
    // same TextFormatOptions, so every value matches on the same page.
    assert.notEqual(api.embedding_gemma, 'not bundled', 'the probe did not run EmbeddingGemma');
    compare('embedding_gemma', api.embedding_gemma, official.embedding_gemma);
    assert.equal(api.embedding_gemma.float.values[0].length, 768);
    report.embedding_gemma_max_error = errors.embedding_gemma ?? 0;
    report.checks.push('embedding-gemma-match-official-javascript');
  }
  // The audio stream, which browsers run emulated on Google's clips mode.
  const stream = api.audio_stream;
  // At the model's rate the emulation is Google's whole clip, every number,
  // the tail included.
  compare('audio_stream', stream['speech-100ms'].chunks, official.audio['speech_16000_hz_mono.wav']);
  assert.equal(stream['speech-100ms'].before_dispose, 4, 'the tail comes with dispose()');
  // At 48 kHz each window is Google's clip of its span, every number, which
  // proves the framing; the stream stamps them 975 ms apart.
  compare('audio_stream', stream['speech-48k'].chunks.map(([, c]) => c), official.stream.spans.map(([, c]) => c));
  assert.deepEqual(stream['speech-48k'].chunks.map(([t]) => t), [0, 975, 1950, 2925, 3900]);
  // Against Google's whole 48 kHz clip: the documented approximation of
  // resampling each window on its own, the gallery's bound for another
  // runtime.
  let approximation = 0;
  official.audio['speech_48000_hz_mono.wav'].forEach(([, categories], i) => {
    const mine = stream['speech-48k'].chunks[i][1];
    assert.equal(mine[0][2], categories[0][2], `48 kHz window ${i}: top category`);
    const scores = new Map(mine.map(([index, score]) => [index, score]));
    for (const [index, score, name] of categories.slice(0, 3)) {
      assert.ok(scores.has(index), `48 kHz window ${i}: ${name} not among the stream's top five`);
      approximation = Math.max(approximation, Math.abs(scores.get(index) - score));
    }
  });
  assert.ok(approximation <= 2 / 256, 'resampled stream vs whole clip: ' + approximation);
  report.audio_stream_48k_vs_whole_clip = approximation;
  assert.equal(stream['lone-half-second'].before_dispose, 0);
  compare('audio_stream', stream['lone-half-second'].chunks, official.stream.lone);
  // The checks' messages, as native platforms give them.
  assert.equal(stream.rate, 'sampleRate: The stream runs at 16000.0 Hz, fixed by its first block');
  assert.equal(stream.timestamp,
    'timestampMilliseconds: Must be nonnegative, strictly increasing and at most 9007199254740');
  assert.equal(stream.stereo, 'accepted');
  report.audio_stream_max_error = errors.audio_stream;
  report.checks.push('audio-stream-match-official-javascript');
  if (microphone) {
    const heard = api.microphone.chunks.flatMap(([, categories]) => categories.map(c => c[2]));
    const stamps = api.microphone.chunks.map(([timestamp]) => timestamp);
    fs.writeFileSync(path.join(evidence, 'microphone.json'), JSON.stringify(api.microphone, null, 2));
    assert.ok(api.microphone.samples >= 32000, 'too little microphone audio');
    assert.ok(heard.includes('Speech'), 'the fake microphone plays speech; heard ' + heard);
    assert.ok(stamps.length >= 2 && stamps.every((t, i) => i === 0 || t > stamps[i - 1]),
      'the microphone stream\'s windows in order: ' + stamps);
    report.checks.push('microphone-speech-classified');
  }
  await wait(page, () => mediapipeTasks.stats().activeWorkers === 0);
  report.checks.push('text-audio-worker-cleanup');
  // Exercise the gallery's default settings as well as the package API.
  await page.goto(gallery);
  await page.getByRole('button', {name: /Text Embedder/}).click();
  await page.getByRole('button', {name: 'Compare', exact: true}).click();
  // The Output card lists the score as "Cosine similarity 0.1234".
  await wait(page, () => /Cosine similarity -?\d+\.\d+/.test(document.body.innerText), null, 60000);
  report.checks.push('gallery-text-embedder-compare');
}

// What macOS logged about the browser's processes, for a run that lost its
// page: the unified log names a WebKit process that went and why.
function saveSystemLog(name) {
  if (process.platform !== 'darwin') return;
  try {
    const log = execFileSync('/usr/bin/log', ['show', '--last', '15m', '--style', 'compact', '--predicate',
      'process == "Playwright" OR process BEGINSWITH "com.apple.WebKit" OR ' +
      '(process == "kernel" AND eventMessage CONTAINS "memorystatus")'],
    {encoding: 'utf8', maxBuffer: 1024 * 1024 * 1024});
    fs.writeFileSync(path.join(evidence, name + '-lost-page-unified.log'), log);
    console.log(log.split('\n')
      .filter(line => /terminat|crash|unresponsive|exceed|kill|memory limit|footprint/i.test(line))
      .filter(line => !/canTerminateAuxiliaryProcess|AutomaticTermination/.test(line))
      .slice(-30).join('\n'));
  } catch (error) {
    console.log('No unified log: ' + error.message);
  }
}

// WebKit on hosted macOS has closed the page mid-suite with no page error or
// failed check (run 38261996089). A suite that loses its page or browser, and
// only that, runs once more on a fresh browser; a failed check still fails at
// once. Each retry is kept in the report and shown as a workflow warning.
async function retryingLostPage(name, checks) {
  const passed = report.checks.length;
  try {
    await checks();
  } catch (error) {
    if (!/Target page, context or browser has been closed|Target crashed/.test(error?.message ?? '')) throw error;
    const reason = error.message.split('\n')[0];
    report.retries.push({suite: name, error: reason, crashed: logs.some(entry => entry.type === 'crash')});
    console.log(`::warning title=${browserName} lost the page::${name} checks: ${reason}. ` +
      'Running them once more on a fresh browser.');
    saveSystemLog(name);
    report.checks.length = passed;
    for (const browser of browsers.splice(0)) await browser.close().catch(() => {});
    await checks();
  }
}

try {
  if (suite === 'text-audio') await retryingLostPage('text-audio', textAudioChecks);
  if (suite === 'all' || suite === 'api') await retryingLostPage('api', apiChecks);
  if ((suite === 'all' || suite === 'api') && browserName === 'chromium' && delegate === 'CPU') {
    await retryingLostPage('ios-user-agent', iosUserAgentCpuCheck);
  }
  if (suite === 'all' || suite === 'camera') await retryingLostPage('camera', cameraChecks);
  assert.equal(logs.filter(entry => entry.type === 'pageerror').length, 0, JSON.stringify(logs));
  report.status = 'passed';
  console.log(JSON.stringify(report, null, 2));
} catch (error) {
  report.status = 'failed';
  report.error = error.stack;
  console.error(error);
  process.exitCode = 1;
} finally {
  for (const browser of browsers) {
    for (const context of browser.contexts()) {
      for (const page of context.pages()) {
        try {
          fs.writeFileSync(path.join(evidence, 'failure-page.html'), await page.content());
          fs.writeFileSync(path.join(evidence, 'capture-diagnostics.json'), JSON.stringify(await page.evaluate(() => ({
            capture:window.testCaptureDiagnostics,
            video: (() => {const v=document.querySelector('video'); return v ? {
              width:v.videoWidth,height:v.videoHeight,readyState:v.readyState,frames:v.getAttribute('data-processed-frames'),
              mediaError:v.error?.message,currentTime:v.currentTime,paused:v.paused,
              sameElement:v === window.testPreviewVideo,
              tracks:[...(v.srcObject?.getTracks() ?? [])].map(t => ({readyState:t.readyState,muted:t.muted,enabled:t.enabled})),
              callbacks:window.testFrameCallbacks?.size,
              stats:globalThis.mediapipeVision?.stats(),
            }: null;})(),
          })),null,2));
          await page.screenshot({path: path.join(evidence, 'failure.png')});
        } catch (_) {}
      }
    }
    await browser.close();
  }
  fs.writeFileSync(path.join(evidence, 'report.json'), JSON.stringify(report, null, 2));
  fs.writeFileSync(path.join(evidence, 'browser-log.json'), JSON.stringify(logs, null, 2));
}

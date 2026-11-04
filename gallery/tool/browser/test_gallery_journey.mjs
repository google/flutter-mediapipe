import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium, firefox, webkit} from 'playwright';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const args = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split('=')));
const browserName = args.browser || 'chromium';
const base = args['base-url'] || 'http://127.0.0.1:8866/flutter-mediapipe/';
const evidence = path.join(repo, 'build/ci-tmp/gallery-journey-' + browserName);
fs.mkdirSync(evidence, {recursive: true});

// This table describes user-facing actions, not which tasks a build contains.
// The release manifest decides that; an unknown bundled task fails the test.
const cases = {
  face_detector: {title: 'Face Detector', sample: 'portrait.jpg', result: /[1-9]\d* faces? detected/},
  face_landmarker: {title: 'Face Landmarker', sample: 'portrait.jpg', result: /[1-9]\d* faces? detected/},
  gesture_recognizer: {title: 'Gesture Recognizer', sample: 'thumb_up.jpg', result: /[1-9]\d* hands? recognized/},
  hand_landmarker: {title: 'Hand Landmarker', sample: 'hands.jpg', result: /[1-9]\d* hands? detected/},
  holistic_landmarker: {title: 'Holistic Landmarker', sample: 'pose.jpg', result: /Body landmarks detected/},
  image_classifier: {title: 'Image Classifier', sample: 'portrait.jpg', result: /[1-9]\d* classes returned/},
  image_embedder: {title: 'Image Embedder', embed: true},
  image_segmenter: {title: 'Image Segmenter', sample: 'portrait.jpg', result: /Segmentation complete/},
  object_detector: {title: 'Object Detector', sample: 'group.jpeg', result: /[1-9]\d* objects? detected/},
  pose_landmarker: {title: 'Pose Landmarker', sample: 'pose.jpg', result: /[1-9]\d* poses? detected/},
  interactive_segmenter: {title: 'Interactive Segmenter', segment: true},
  audio_classifier: {title: 'Audio Classifier', audio: true},
  // A category row reads "<category> <score>"; the sample's own category
  // must score at least 0.5, not merely be listed.
  language_detector: {title: 'Language Detector', text: true, row: /^fr (0\.[5-9]|1\.0)/},
  text_classifier: {title: 'Text Classifier', text: true, row: /^positive (0\.[5-9]|1\.0)/},
  text_embedder: {title: 'Text Embedder', text: true, compare: true, result: /^Cosine similarity -?\d+\.\d+$/},
  embedding_gemma: {title: 'EmbeddingGemma', text: true, compare: true, result: /^Cosine similarity -?\d+\.\d+$/},
  // What Google's Python API answers the page's sample with Laya: a refund,
  // about shipping, and unhappy (1.28 of 0 to 4).
  decision_maker: {title: 'Decision Maker', decision: [
    ['Yes / No', /^Yes$/],
    // Its expected option is the first one, which a tie also picks.
    ['Choice', /^shipping$/, ['shipping', 'billing', 'account', 'other']],
    ['Score', /^1\.(2[3-9]|3[0-3])$/],
  ]},
  // Universal Embedder compares a sentence about a dog with the dog photo,
  // then the elephant; Semantic Retriever ranks the dog document first for
  // the puppy query, as Google's Python API does (0.82).
  universal_embedder: {title: 'Universal Embedder', universal: true},
  semantic_retriever: {title: 'Semantic Retriever', retrieve: /^A dog chases a ball/},
};

// The delegates each page must offer and run come from the coverage matrix the
// gate enforces: a required web GPU cell that the UI stops offering fails here.
const matrix = JSON.parse(fs.readFileSync(path.join(repo, 'tool/coverage/matrix.json'), 'utf8')).cells;
const delegatesFor = id => ['cpu', 'gpu'].filter(delegate => matrix[id]?.web?.[delegate] === 'required');

const report = {browser: browserName, checks: [], tasks: [], errors: [], steps: [], events: []};
// Each step and browser event carries the wall clock, to line up with the
// browser's own logs.
let step = 'launch';
const enter = name => {
  step = name;
  report.steps.push(`${new Date().toISOString()} ${name}`);
};
// A browser that drops the page leaves Playwright reporting only that it is
// closed; these events say which part went and during which step.
let closing = false;
const lifecycle = event => {
  if (closing) return;
  const line = `${new Date().toISOString()} ${step}: ${event}`;
  report.events.push(line);
  console.log(`Journey event: ${line}`);
};
// Hosted Linux has no GPU, and Google's vision tasks need a WebGL context even
// on CPU, so allow software WebGL there as test_browser.mjs does. Each engine
// also gets a fake camera: Chromium plays the face fixture when it has been
// prepared, Firefox its synthetic stream, and WebKit its mock capture device.
const linux = process.platform === 'linux';
const fixture = path.join(repo, 'build/ci-tmp/web-camera.y4m');
const browser = await ({chromium, firefox, webkit}[browserName]).launch({
  headless: args.headed !== 'true',
  ...(browserName === 'chromium' ? {
    channel: 'chromium',
    args: [
      '--use-fake-ui-for-media-stream',
      '--use-fake-device-for-media-stream',
      ...(fs.existsSync(fixture) ? ['--use-file-for-fake-video-capture=' + fixture] : []),
      ...(linux ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : []),
    ],
  } : {}),
  ...(browserName === 'firefox' ? {firefoxUserPrefs: {
    'media.navigator.streams.fake': true,
    'media.navigator.permission.disabled': true,
    ...(linux ? {'webgl.force-enabled': true} : {}),
  }} : {}),
});
browser.on('disconnected', () => lifecycle('browser disconnected'));
let page;
let hardwareWebGpu = false;
try {
  const context = await browser.newContext({viewport: {width: 1280, height: 900}});
  context.on('close', () => lifecycle('context closed'));
  try {
    await context.grantPermissions(['camera'], {origin: new URL(base).origin});
  } catch {
    // Firefox takes camera access from the preference above instead.
  }
  page = await context.newPage();
  page.on('crash', () => lifecycle('page crashed'));
  page.on('close', () => lifecycle('page closed'));
  // Each error names the step it happened in; some engines throw errors with
  // no message, so the name and the top of the stack are kept too.
  enter('load');
  page.on('pageerror', error => report.errors.push(
    `${step}: ${error.name || 'Error'}: ${error.message || '(no message)'}` +
    (error.stack ? ` | ${error.stack.split('\n').slice(0, 3).join(' / ')}` : '')));
  page.on('response', response => {
    if (response.status() >= 400) report.errors.push(`${step}: ${response.status()} ${response.url()}`);
  });
  const manifestResponse = await page.request.get(new URL('assets/assets/manifest.json', base).href);
  assert.ok(manifestResponse.ok(), 'release manifest unavailable');
  const manifest = await manifestResponse.json();
  // Google's browser runtime has no Proofreader or Summarizer (UP-034), so a
  // web build bundles them for the text probe's comparison only; the gallery
  // shows their cards, not tiles. EmbeddingGemma is a tile.
  const probeOnly = new Set(['text_proofreader', 'text_summarizer']);
  for (const id of manifest.tasks.filter(id => !probeOnly.has(id))) {
    assert.ok(cases[id], `new bundled task ${id} needs a gallery journey`);
  }
  // Flutter renders sidebar links as <a> without an href, which has no link
  // role, so match the item's own anchor by its exact text.
  const sidebarItem = title => page.locator('a[flt-tappable]')
    .filter({hasText: new RegExp(`^${title}$`)});
  // The sidebar marks its item current in the frame that builds the item's
  // page, so nothing after this finds a control of the previous page.
  const openedPage = title => page.locator('a[flt-tappable][aria-current="true"]')
    .filter({hasText: new RegExp(`^${title}$`)});
  // A segment of a CPU/GPU control; clicking waits until the page enables it.
  const delegateButton = delegate => page.getByRole('button', {name: delegate.toUpperCase(), exact: true});
  // The status line under a running feed reads "20.1 fps · 5 ms · GPU", with a
  // frame rate above zero once frames arrive on that delegate.
  const liveFrames = delegate =>
    page.getByText(new RegExp(`^(?!0\\.0 fps)\\d+\\.\\d fps · \\d+ ms · ${delegate.toUpperCase()}$`));
  // A runtime that embeds every input as zeros scores every option the same,
  // and a tie reads as the first option (UP-054), so options whose score
  // rows ("shipping 0.87") all read the same fail here.
  const assertScoresDiffer = async (names, what) => {
    const scores = [];
    for (const name of names) {
      const row = (await page.getByText(new RegExp(`^${name} \\d\\.\\d{2}$`)).first().textContent()) ?? '';
      scores.push(row.slice(name.length + 1));
    }
    assert.ok(new Set(scores).size > 1,
      `${what}: every option scored ${scores[0]}, as when Google's runtime embeds every input as zeros (UP-054)`);
  };
  // A still image's status line names the delegate that produced it.
  const stillRan = delegate =>
    page.getByText(new RegExp(`Inference \\d+\\.\\d ms · ${delegate.toUpperCase()}$`));
  // CI's browsers have no microphone with speech on it, so the audio page
  // plays the speech sample through its microphone path instead.
  await page.goto(base + (base.includes('?') ? '&' : '?') + 'microphone=sample');
  await sidebarItem('Home').waitFor({timeout: 120000});
  // Google's browser Decision Maker answers only on a hardware WebGPU adapter,
  // by its own rule (UP-049), and its Universal Embedder creates a WebGPU
  // device for itself (UP-052); elsewhere the gallery shows their cards.
  hardwareWebGpu = await page.evaluate(async () => {
    const adapter = await navigator.gpu?.requestAdapter({powerPreference: 'high-performance'});
    const info = adapter?.info ?? {};
    return !!adapter && !adapter.isFallbackAdapter &&
      !/fallback|swiftshader|llvmpipe|software|lavapipe/i.test(`${info.vendor} ${info.architecture} ${info.description}`);
  });
  // On a hardware adapter WebKit still runs no EmbeddingGemma 2 model, as
  // Google's runtime embeds every input there as zeros (UP-054): the
  // retrieval tasks and Hungry Fish are cards, and Decision Maker runs Laya.
  const webKitZeros = browserName === 'webkit' && hardwareWebGpu;
  const refused = new Set(!hardwareWebGpu ? ['decision_maker', 'universal_embedder', 'semantic_retriever']
    : webKitZeros ? ['universal_embedder', 'semantic_retriever'] : []);
  const refusedReason = webKitZeros ? /UP-054/ : /UP-049|UP-052/;
  // --tasks=a,b visits only those of the bundled tasks.
  const only = args.tasks ? new Set(args.tasks.split(',')) : null;
  for (const id of refused) if (only && !only.has(id)) refused.delete(id);
  const expected = manifest.tasks.filter(id =>
    !probeOnly.has(id) && !refused.has(id) && (!only || only.has(id)));
  assert.ok(expected.length + refused.size > 0, 'empty release task list');
  for (const id of refused) {
    if (!manifest.tasks.includes(id)) continue;
    // The home page's card reads "<title>. <the capability query's reason>",
    // so each refused task's own card is read, not the first reason on the page.
    enter(`${id}:refused`);
    const card = page.getByText(new RegExp(`^${cases[id].title}\\. `)).first();
    await card.waitFor({timeout: 120000});
    const text = await card.textContent();
    assert.match(text, refusedReason, `${id}: its card reads "${text}"`);
    report.checks.push(`${id}:refused`);
  }

  for (const id of expected) {
    const spec = cases[id];
    enter(`${id}:open`);
    await sidebarItem(spec.title).click();
    await openedPage(spec.title).waitFor();
    if (spec.sample) {
      const delegates = delegatesFor(id);
      assert.ok(delegates.length > 0, `${id} has no required web delegate`);
      // The page opens with the camera running. Each delegate must keep frames
      // coming, and the second is reached by switching while the camera runs.
      for (const delegate of delegates) {
        enter(`${id}:${delegate}:live`);
        if (delegates.length > 1) await delegateButton(delegate).click({timeout: 120000});
        await liveFrames(delegate).waitFor({timeout: 120000});
        report.checks.push(`${id}:${delegate}:live`);
      }
      await page.screenshot({path: path.join(evidence, `${id}-live.png`)});
      enter(`${id}:mode`);
      await page.getByRole('button', {name: 'Still image', exact: true}).click();
      const choose = page.getByRole('button', {name: 'Choose image'});
      await choose.waitFor();
      const chooserPromise = page.waitForEvent('filechooser');
      await choose.click();
      const chooser = await chooserPromise;
      await chooser.setFiles(path.join(repo, 'gallery/assets/samples', spec.sample));
      // The image runs on the delegate the camera ended on; switching back
      // runs it again on the other.
      for (const delegate of [...delegates].reverse()) {
        enter(`${id}:${delegate}:still`);
        if (delegates.length > 1) await delegateButton(delegate).click({timeout: 120000});
        await stillRan(delegate).waitFor({timeout: 120000});
        await page.getByText(spec.result).waitFor();
        report.checks.push(`${id}:${delegate}:still`);
      }
      // The status line opens with the chosen file's name.
      assert.equal(await page.getByText(new RegExp(`^${spec.sample.replace('.', '\\.')} · `)).count(), 1);
      await page.screenshot({path: path.join(evidence, `${id}-still.png`)});
      // The video file mode runs the bundled clip in video mode, every frame
      // in order with the file's own timestamp. The status line names the
      // count only when every frame answered with its own timestamp and none
      // repeated one, so this match is the check.
      enter(`${id}:video`);
      await page.getByRole('button', {name: 'Video file', exact: true}).click();
      const finished = page.getByText(/^scene\.mp4 · 90 frames done · \d+\.\d ms per frame · (CPU|GPU)$/);
      await finished.waitFor({timeout: 300000});
      console.log(`${id} video file: ${await finished.textContent()}`);
      report.checks.push(`${id}:video`);
      await page.screenshot({path: path.join(evidence, `${id}-video.png`)});
    } else if (spec.embed) {
      // The page opens comparing Dog with Cat; each delegate compares them
      // again, and the status line names the delegate that did.
      const delegates = delegatesFor(id);
      assert.ok(delegates.length > 0, `${id} has no required web delegate`);
      const similarity = /^Cosine similarity -?\d\.\d{4}$/;
      for (const delegate of delegates) {
        enter(`${id}:${delegate}:compare`);
        if (delegates.length > 1) await delegateButton(delegate).click({timeout: 120000});
        await stillRan(delegate).waitFor({timeout: 120000});
        await page.getByText(similarity).waitFor();
        report.checks.push(`${id}:${delegate}:compare`);
      }
      // The same sample on both sides is identical.
      enter(`${id}:same`);
      await page.locator('[flt-semantics-identifier="image-embedder-2-samples"]')
        .getByRole('button', {name: 'Dog', exact: true}).click();
      await page.getByText(/^Cosine similarity 1\.0000$/).waitFor({timeout: 120000});
      // An upload replaces the first image.
      enter(`${id}:upload`);
      const chooserPromise = page.waitForEvent('filechooser');
      await page.locator('[flt-semantics-identifier="image-embedder-1-upload"]')
        .getByRole('button').click();
      const chooser = await chooserPromise;
      await chooser.setFiles(path.join(repo, 'gallery/assets/samples/portrait.jpg'));
      await page.getByText(/^Cosine similarity (?!1\.0000$)-?\d\.\d{4}$/).waitFor({timeout: 120000});
      report.checks.push(`${id}:upload`);
      await page.screenshot({path: path.join(evidence, `${id}.png`)});
    } else if (spec.text) {
      enter(`${id}:run`);
      await page.getByRole('button', {name: spec.compare ? 'Compare' : 'Run', exact: true}).click();
      await page.getByText(spec.row || spec.result)
        .waitFor({timeout: 120000});
      await page.getByText(/Done in \d+\.\d ms/).waitFor();
      report.checks.push(`${id}:cpu:run`);
    } else if (spec.universal) {
      // The first comparison fetches Google's 388 MB model from Hugging Face.
      enter(`${id}:compare`);
      const similarity = page.locator('[flt-semantics-identifier="universal-similarity"]');
      const error = page.locator('[flt-semantics-identifier="universal-error"]');
      const value = async () => {
        const text = (await similarity.getAttribute('aria-label')) ?? (await similarity.textContent()) ?? '';
        return parseFloat(text.replace(/^Cosine similarity\s*/, ''));
      };
      await page.getByRole('button', {name: 'Compare', exact: true}).click();
      const undefinedSimilarity = similarity.filter({hasText: /NaN/});
      await similarity.filter({hasText: /-?\d\.\d{4}/}).or(error).or(undefinedSimilarity).first().waitFor({timeout: 600000});
      assert.equal(await error.count(), 0, `${id}: ${await page.locator('flt-semantics').allInnerTexts()}`);
      assert.equal(await undefinedSimilarity.count(), 0, `${id}: the similarity is NaN, as when Google's runtime embeds every input as zeros (UP-054)`);
      const dog = await value();
      enter(`${id}:elephant`);
      await page.locator('[flt-semantics-identifier="universal-2-samples"]')
        .getByRole('button', {name: 'Elephant', exact: true}).click();
      await page.getByRole('img', {name: 'Image 2: Elephant'}).or(page.getByText('Image 2: Elephant')).first().waitFor({timeout: 120000});
      await page.getByRole('button', {name: 'Compare', exact: true}).click();
      const deadline = Date.now() + 120000;
      let elephant = dog;
      while (elephant === dog && Date.now() < deadline) {
        await page.waitForTimeout(500);
        elephant = await value();
      }
      assert.ok(elephant < dog, `${id}: dog text vs dog photo ${dog}, vs elephant ${elephant}`);
      report.checks.push(`${id}:cpu:compare`);
      await page.screenshot({path: path.join(evidence, `${id}.png`)});
    } else if (spec.retrieve) {
      // The first search fetches Google's 388 MB model from Hugging Face.
      enter(`${id}:search`);
      const top = page.locator('[flt-semantics-identifier="retrieval-top"]');
      const error = page.getByText('Error', {exact: true});
      // Zero vectors match no document, even at a minimum similarity of 0.
      const none = page.getByText(/^0 of \d+ documents$/);
      await page.getByRole('button', {name: 'Search', exact: true}).click();
      await top.or(error).or(none).first().waitFor({timeout: 600000});
      assert.equal(await error.count(), 0, `${id}: ${await page.locator('flt-semantics').allInnerTexts()}`);
      assert.equal(await none.count(), 0, `${id}: no document matched, as when Google's runtime embeds every input as zeros (UP-054)`);
      assert.match((await top.textContent()) ?? '', spec.retrieve, `${id}: best match`);
      report.checks.push(`${id}:cpu:search`);
      await page.screenshot({path: path.join(evidence, `${id}.png`)});
    } else if (spec.decision) {
      const error = page.getByText('Error', {exact: true});
      for (const [kind, answer, rows] of spec.decision) {
        enter(`${id}:${kind}`);
        await page.getByRole('button', {name: kind, exact: true}).click();
        await page.getByRole('button', {name: 'Ask', exact: true}).click();
        // The first question fetches Google's 678 MB model from its bucket.
        await page.getByText(answer).first().or(error).first().waitFor({timeout: 600000});
        assert.equal(await error.count(), 0,
          `${id} ${kind}: ${await page.locator('flt-semantics').allInnerTexts()}`);
        if (rows) await assertScoresDiffer(rows, `${id} ${kind}`);
        report.checks.push(`${id}:gpu:${kind}`);
      }
      await page.screenshot({path: path.join(evidence, `${id}.png`)});
      if (webKitZeros) {
        // Hungry Fish plays on EmbeddingGemma 2, so in WebKit it is a card.
        enter(`${id}:game-refused`);
        assert.equal(await sidebarItem('Hungry Fish').count(), 0, `${id}: Hungry Fish is a tile in WebKit`);
        await sidebarItem('Home').click();
        await page.getByText(/UP-054/).first().waitFor({timeout: 120000});
        report.checks.push(`${id}:game-refused`);
      } else {
        // Hungry Fish, the same runtime playing a game: Google's wording gets
        // every sentence the game writes right, so each decision matches.
        enter(`${id}:game`);
        await sidebarItem('Hungry Fish').click();
        await openedPage('Hungry Fish').waitFor();
        await page.getByRole('button', {name: 'Play', exact: true}).click();
        const score = page.getByText(/^\d+ decisions · \d+ matched the scene$/);
        const deadline = Date.now() + 600000;
        let decisions = 0;
        let matched = 0;
        while (decisions < 5) {
          assert.equal(await error.count(), 0,
            `${id} game: ${await page.locator('flt-semantics').allInnerTexts()}`);
          assert.ok(Date.now() < deadline, `${id} game: five decisions`);
          [decisions, matched] = ((await score.textContent()) ?? '').match(/\d+/g)?.map(Number) ?? [0, 0];
          await page.waitForTimeout(250);
        }
        await assertScoresDiffer(['chase', 'flee', 'explore'], `${id} game`);
        assert.equal(matched, decisions, `${id} game: every decision matches the scene`);
        await page.getByRole('button', {name: 'Pause', exact: true}).click();
        await page.screenshot({path: path.join(evidence, `${id}-game.png`)});
        report.checks.push(`${id}:gpu:game`);
      }
    } else if (spec.audio) {
      enter(`${id}:run`);
      // The first window of the speech clip is heard as speech.
      await page.getByText(/^Speech \d\.\d{2}$/).first().waitFor({timeout: 120000});
      await page.getByText(/Done in \d+\.\d ms/).waitFor();
      report.checks.push(`${id}:cpu:run`);
      // The microphone mode on the speech sample as it plays: the stream's
      // windows start 975 ms apart, and each hears speech.
      enter(`${id}:stream`);
      await page.getByRole('button', {name: 'Microphone', exact: true}).click();
      await page.getByText('Waiting for the first window.').waitFor({timeout: 120000});
      const windowStart = /^\d+\.\d{3} s$/;
      const deadline = Date.now() + 120000;
      while (await page.getByText(windowStart).count() < 4) {
        assert.ok(Date.now() < deadline, 'four windows of the stream');
        await page.waitForTimeout(250);
      }
      const starts = (await page.getByText(windowStart).allInnerTexts())
        .map(text => Math.round(parseFloat(text) * 1000)).sort((a, b) => a - b);
      assert.deepEqual(starts.slice(0, 4), [0, 975, 1950, 2925]);
      assert.ok(await page.getByText(/^Speech \d\.\d{2}$/).count() >= starts.length,
        'every window of the speech sample hears speech');
      report.checks.push(`${id}:cpu:stream`);
      // Leaving the mode flushes the stream; the clip plays again.
      enter(`${id}:clips`);
      await page.getByRole('button', {name: 'Clips', exact: true}).click();
      await page.getByText(/Done in \d+\.\d ms/).waitFor({timeout: 120000});
    } else if (spec.segment) {
      const delegates = delegatesFor(id);
      assert.ok(delegates.length > 0, `${id} has no required web delegate`);
      for (const delegate of delegates) {
        enter(`${id}:${delegate}:tap`);
        // Switching reopens the task, so the image is tapped again after it.
        if (delegates.length > 1) await delegateButton(delegate).click({timeout: 120000});
        // Wait for the newly opened delegate's canvas before clicking. The
        // old canvas can still be visible when the delegate click returns.
        // Use real pointer events; a semantics tap has no position.
        const image = page.locator(`[flt-semantics-identifier="segment-canvas-${delegate}"]`);
        await image.waitFor({timeout: 120000});
        const box = await image.boundingBox();
        await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
        await page.getByText(new RegExp(
          `\\d+\\.\\d ms · \\d+ requests · \\d+ coalesced · ${delegate.toUpperCase()}$`,
        )).waitFor({timeout: 120000});
        report.checks.push(`${id}:${delegate}:tap`);
        // Exclude and Lasso through the page, as the Flutter journey draws
        // them: a drag with each brush, counted on the Selection card and
        // segmented on this delegate. Multi-point strokes matter here: WebGL
        // draws nothing for a single point.
        const requests = async () => {
          const text = await page.getByText(/\d+ requests/).first().textContent();
          return Number(/(\d+) requests/.exec(text ?? '')?.[1] ?? 0);
        };
        const until = async (what, condition) => {
          const end = Date.now() + 120000;
          while (!(await condition())) {
            if (Date.now() > end) throw new Error(`${id}: timed out waiting for ${what} on ${delegate}`);
            await page.waitForTimeout(250);
          }
        };
        const drag = async points => {
          await page.mouse.move(...points[0]);
          await page.mouse.down();
          for (const point of points.slice(1)) await page.mouse.move(...point, {steps: 8});
          await page.mouse.up();
        };
        const at = (fx, fy) => [box.x + box.width * fx, box.y + box.height * fy];
        const summary = text => page.getByText(text, {exact: true});
        const brush = name => page.getByRole('button', {name, exact: true});
        let before = await requests();
        enter(`${id}:${delegate}:exclude`);
        await brush('Exclude').click();
        await drag([at(0.4, 0.5), at(0.6, 0.5)]);
        await until('the Exclude stroke', async () =>
          await requests() > before && await summary('1 include · 1 exclude').count() === 1);
        report.checks.push(`${id}:${delegate}:exclude`);
        before = await requests();
        enter(`${id}:${delegate}:lasso`);
        await brush('Lasso').click();
        await drag([at(0.3, 0.3), at(0.7, 0.3), at(0.7, 0.7), at(0.3, 0.7)]);
        await until('the lasso', async () =>
          await requests() > before && await summary('1 include · 1 exclude · 1 lasso').count() === 1);
        report.checks.push(`${id}:${delegate}:lasso`);
        await brush('Include').click();
      }
      await page.screenshot({path: path.join(evidence, `${id}.png`)});
    }
    report.tasks.push(id);
  }
  assert.deepEqual(new Set(report.tasks), new Set(expected));
  enter('end');
  assert.deepEqual(report.errors, []);
  report.status = 'passed';
  console.log(`Gallery journey passed: ${report.tasks.join(', ')}`);
  console.log(`Checks: ${report.checks.join(', ')}`);
} catch (error) {
  report.status = 'failed';
  report.error = String(error.stack || error);
  console.error(error);
  process.exitCode = 1;
  // Only a page that is still open can show where the step stopped.
  await page?.screenshot({path: path.join(evidence, 'failure.png'), timeout: 10000}).catch(() => {});
} finally {
  fs.writeFileSync(path.join(evidence, 'report.json'), JSON.stringify(report, null, 2) + '\n');
  closing = true;
  await browser.close();
}

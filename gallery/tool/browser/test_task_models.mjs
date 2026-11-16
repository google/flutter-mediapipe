import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium, firefox, webkit} from 'playwright';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const args = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split('=')));
const browserName = args.browser || 'chromium';
const base = args['base-url'] || 'http://127.0.0.1:8866/flutter-mediapipe/';
const evidence = path.join(repo, 'build/ci-tmp/task-models-' + browserName);
fs.mkdirSync(evidence, {recursive: true});

// The models a live page's Model menu offers beside its own, as the task's
// guide names them, each with the file its Info names and the result the
// portrait gives.
const cases = [
  {title: 'Face Detector', standard: 'BlazeFace (short-range)', result: /^portrait\.jpg · 1 face detected · /, models: [
    ['BlazeFace (full-range)', 'blaze_face_full_range.tflite'],
    ['BlazeFace Sparse (full-range)', 'blaze_face_full_range_sparse.tflite'],
  ]},
];
const ids = {'Face Detector': 'face_detector'};

// The delegates each page must run come from the coverage matrix, as in
// test_gallery_journey.mjs.
const matrix = JSON.parse(fs.readFileSync(path.join(repo, 'tool/coverage/matrix.json'), 'utf8')).cells;
const delegatesFor = id => ['cpu', 'gpu'].filter(delegate => matrix[id]?.web?.[delegate] === 'required');

// Hosted Linux has no GPU, so allow software WebGL there as the journey does,
// and give each engine a fake camera for the page's opening feed.
const linux = process.platform === 'linux';
const browser = await ({chromium, firefox, webkit}[browserName]).launch({
  headless: args.headed !== 'true',
  ...(browserName === 'chromium' ? {
    channel: 'chromium',
    args: [
      '--use-fake-ui-for-media-stream',
      '--use-fake-device-for-media-stream',
      ...(linux ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : []),
    ],
  } : {}),
  ...(browserName === 'firefox' ? {firefoxUserPrefs: {
    'media.navigator.streams.fake': true,
    'media.navigator.permission.disabled': true,
    ...(linux ? {'webgl.force-enabled': true} : {}),
  }} : {}),
});
const report = {browser: browserName, checks: [], errors: []};
let page;
try {
  const context = await browser.newContext({viewport: {width: 1280, height: 900}});
  try {
    await context.grantPermissions(['camera'], {origin: new URL(base).origin});
  } catch {
    // Firefox takes camera access from the preference above instead.
  }
  page = await context.newPage();
  page.on('pageerror', error => report.errors.push(`${error.name || 'Error'}: ${error.message || '(no message)'}`));
  const sidebarItem = title => page.locator('a[flt-tappable]')
    .filter({hasText: new RegExp(`^${title}$`)});
  const openedPage = title => page.locator('a[flt-tappable][aria-current="true"]')
    .filter({hasText: new RegExp(`^${title}$`)});
  const delegateButton = delegate => page.getByRole('button', {name: delegate.toUpperCase(), exact: true});
  const stillRan = delegate =>
    page.getByText(new RegExp(`Inference \\d+\\.\\d ms · ${delegate.toUpperCase()}$`));
  // The settings panel, the Model menu with it, is disabled while the camera
  // starts or the task is rebuilt, so the page is ready once frames come.
  const liveFrames = () => page.getByText(/^(?!0\.0 fps)\d+\.\d fps · \d+ ms · (CPU|GPU)$/);
  const sample = fs.readFileSync(path.join(repo, 'gallery/assets/samples/portrait.jpg'));

  for (const spec of cases) {
    const delegates = delegatesFor(ids[spec.title]);
    assert.ok(delegates.length > 0, `${spec.title} has no required web delegate`);
    for (const [name, file] of spec.models) {
      // Each model starts from a fresh page, so its result is its own.
      await page.goto(base);
      await sidebarItem(spec.title).click({timeout: 120000});
      await openedPage(spec.title).waitFor();
      await liveFrames().waitFor({timeout: 120000});
      await page.getByRole('button', {name: new RegExp(spec.standard.replace(/[()]/g, '\\$&'))}).click();
      await page.getByRole('menuitem', {name: new RegExp(`^${name.replace(/[()]/g, '\\$&')} · `)}).click();
      await page.getByRole('button', {name: new RegExp(`${name.replace(/[()]/g, '\\$&')} · `)}).waitFor();
      // Frames again are the chosen model's, so the page is ready for the
      // still image.
      await liveFrames().waitFor({timeout: 300000});
      await page.getByRole('button', {name: 'Still image', exact: true}).click();
      const choose = page.getByRole('button', {name: 'Choose image'});
      await choose.waitFor();
      const chooserPromise = page.waitForEvent('filechooser');
      await choose.click();
      const chooser = await chooserPromise;
      await chooser.setFiles({name: 'portrait.jpg', mimeType: 'image/jpeg', buffer: sample});
      // The image runs on the delegate the page has; switching runs it again
      // on the other.
      for (const delegate of [...delegates].reverse()) {
        if (delegates.length > 1) await delegateButton(delegate).click({timeout: 120000});
        await stillRan(delegate).waitFor({timeout: 300000});
        await page.getByText(spec.result).waitFor();
        report.checks.push(`${file}:${delegate}`);
      }
      // Info names the chosen model's file, not the page's own.
      await page.getByRole('button', {name: /Info|About this task/}).first().click();
      await page.getByText(file, {exact: true}).waitFor();
      report.checks.push(`${file}:info`);
      await page.screenshot({path: path.join(evidence, `${file}.png`)});
      await page.keyboard.press('Escape');
    }
  }
  assert.deepEqual(report.errors, []);
  console.log(`Task models passed in ${browserName}: ${report.checks.join(', ')}`);
} catch (error) {
  // What the page showed when a step gave up, for the evidence upload.
  if (page) {
    await page.screenshot({path: path.join(evidence, 'failure.png')}).catch(() => {});
    report.failure = await page.locator('flt-semantics').allInnerTexts().catch(() => []);
  }
  throw error;
} finally {
  fs.writeFileSync(path.join(evidence, 'report.json'), JSON.stringify(report, null, 2) + '\n');
  await browser.close();
}

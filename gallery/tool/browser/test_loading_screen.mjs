// The page's loading screen and a camera demo's model progress, under what a
// network can do to them. Every wait is on a request this test holds or fails
// itself, so nothing here depends on how fast the runner or the network is;
// every other origin, the runtime's CDN among them, is refused.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const base = process.env.GALLERY_WEB_URL || 'http://127.0.0.1:8866/flutter-mediapipe/';
const evidence = path.join(repo, 'build/ci-tmp/loading-screen-web');
fs.mkdirSync(evidence, {recursive: true});
// As test_browser.mjs's --first-load-timeout in CI.
const firstLoad = 120000;
const tile = page => page.getByRole('button', {name: /Face Landmarker/});
const splash = page => page.locator('#splash');
// It goes in the frame that draws the home page, so with that page up there is
// nothing to wait for.
const gone = async page => assert.equal(await splash(page).count(), 0);
const shot = (page, name) => page.screenshot({path: path.join(evidence, `${name}.png`)});
const report = {checks: [], requests: {}};

const browser = await chromium.launch({
  channel: 'chromium',
  headless: true,
  args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'],
});

// Runs [check] on a new page, failing on any error the page itself throws
// unless [pageErrors] says it expects them.
const run = async (name, check, {pageErrors = false} = {}) => {
  const context = await browser.newContext({viewport: {width: 1280, height: 900}});
  await context.grantPermissions(['camera'], {origin: new URL(base).origin});
  await context.route(url => url.origin !== new URL(base).origin, route => route.abort());
  const page = await context.newPage();
  const errors = [];
  const requests = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('request', request => requests.push(request.url()));
  try {
    await check(page, requests);
    if (!pageErrors) assert.deepEqual(errors, []);
    report.checks.push(name);
    console.log(`Loading screen: ${name} passed.`);
  } catch (error) {
    await page.screenshot({path: path.join(evidence, `failure-${name}.png`), timeout: 10000}).catch(() => {});
    throw new Error(`Loading screen: ${name} failed: ${error.message}`, {cause: error});
  } finally {
    report.requests[name] = [...new Set(requests.map(url => new URL(url).origin))].sort();
    await context.close();
  }
};

try {
  await run('first-paint', async (page, requests) => {
    // The screen must be up, in the theme's colours, before any of the app has
    // arrived. Holding the app also holds the page's load event, so this does
    // not wait for it.
    let release;
    const held = new Promise(resolve => release = resolve);
    await page.route('**/main.dart.js', async route => {
      await held;
      await route.continue();
    });
    await page.goto(base, {waitUntil: 'commit'});
    await splash(page).locator('.title').waitFor({timeout: firstLoad});
    const painted = await page.evaluate(() => {
      const style = selector => getComputedStyle(document.querySelector(selector));
      return {
        page: style('body').backgroundColor,
        screen: style('#splash').backgroundColor,
        mark: style('#splash .mark').backgroundColor,
        role: document.querySelector('#splash').getAttribute('role'),
      };
    });
    assert.deepEqual(painted, {
      page: 'rgb(255, 255, 255)',
      screen: 'rgb(255, 255, 255)',
      mark: 'rgb(26, 115, 232)',
      role: 'progressbar',
    });
    await shot(page, 'first-paint');

    release();
    await tile(page).waitFor({timeout: firstLoad});
    await gone(page);
    await shot(page, 'ready');
    // Home needs nothing but the page's own origin.
    const origin = new URL(base).origin;
    assert.deepEqual(requests.filter(url => /^https?:/.test(url) && new URL(url).origin !== origin), []);
    await tile(page).click();
    await page.getByRole('button', {name: 'Still image', exact: true}).waitFor({timeout: firstLoad});
  });

  await run('font-503', async page => {
    // Flutter holds its first frame for the fonts, so one that fails must not
    // leave the screen up.
    let refused = 0;
    await page.route('**/assets/fonts/Roboto-*.ttf', route => {
      refused++;
      return route.fulfill({status: 503, body: 'Service Unavailable'});
    });
    await page.goto(base);
    await tile(page).waitFor({timeout: firstLoad});
    await gone(page);
    assert.equal(refused, 3);
    await shot(page, 'font-503');
  });

  await run('app-503', async page => {
    // The app cannot report its own failure to arrive, so the page does.
    await page.clock.install();
    await page.route('**/main.dart.js', route => route.fulfill({status: 503, body: 'Service Unavailable'}));
    await page.goto(base);
    const note = splash(page).locator('.note');
    assert.equal(await note.textContent(), 'Loading...');
    await page.clock.fastForward(30001);
    await page.getByText(/taking longer than usual/).waitFor({timeout: 10000});
    await shot(page, 'app-503');
  }, {pageErrors: true});

  await run('model-progress', async page => {
    // A model that has not arrived shows its download, sized from the manifest
    // whatever the response says, and the camera demo moves on once it does.
    let release;
    const held = new Promise(resolve => release = resolve);
    await page.route(/\/assets\/mediapipe\/[0-9a-f]{64}$/, async route => {
      await held;
      await route.continue();
    });
    await page.goto(base);
    await tile(page).click();
    const downloading = page.getByText(/^Downloading model \d+%/);
    await downloading.waitFor({timeout: firstLoad});
    await page.getByText(/^\d+\.\d \/ \d+\.\d MB$/).waitFor();
    await shot(page, 'model-progress');
    release();
    await downloading.waitFor({state: 'detached', timeout: firstLoad});
  });

  await run('cdn-refused', async page => {
    // With the runtime's CDN gone (see run) the warm-up must fail quietly and
    // leave the worker to report it, by name, on the page.
    await page.goto(base);
    await tile(page).click();
    await page.getByText(/Failed to fetch/).first().waitFor({timeout: firstLoad});
    await shot(page, 'cdn-refused');
  });

  console.log('Loading screen passed in Chromium.');
} finally {
  fs.writeFileSync(path.join(evidence, 'report.json'), JSON.stringify(report, null, 2) + '\n');
  await browser.close();
}

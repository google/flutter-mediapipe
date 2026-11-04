import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const base = process.argv.find(value => value.startsWith('--base-url='))?.split('=')[1]
  ?? 'http://localhost:8866/flutter-mediapipe/';
const evidence = path.join(repo, 'build/ci-tmp/worker-overlays');
fs.mkdirSync(evidence, {recursive: true});

const browser = await chromium.launch({channel: 'chromium', args: [
  '--use-fake-device-for-media-stream',
  '--use-file-for-fake-video-capture=' + path.join(repo, 'build/ci-tmp/web-camera-hand.y4m'),
  ...(process.platform === 'linux' ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : []),
]});
try {
  const context = await browser.newContext({viewport: {width: 1280, height: 800}});
  await context.grantPermissions(['camera'], {origin: new URL(base).origin});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.stack));
  await page.goto(base + (base.includes('?') ? '&' : '?') + 'test-hooks');
  await page.getByRole('button', {name: /Gesture Recognizer/}).click();

  for (const delegate of ['cpu', 'gpu']) {
    await page.getByRole('button', {name: delegate.toUpperCase(), exact: true}).click({timeout: 120000});
    await page.waitForFunction(expected => {
      const video = document.querySelector('video');
      return video?.getAttribute('data-delegate') === expected &&
        Number(video.getAttribute('data-processed-frames')) >= 4 &&
        video.getAttribute('data-landmarks') === '21';
    }, delegate, {timeout: 120000});
    const canvas = page.locator('canvas[data-worker-overlay]');
    await canvas.waitFor({timeout: 30000});
    assert.equal(await canvas.count(), 1, `${delegate} must use one worker overlay`);
    const layer = await canvas.evaluate(element => ({
      transform: element.style.transform,
      width: element.width,
      height: element.height,
    }));
    assert.equal(layer.transform, '', `${delegate} must mirror shapes without mirroring text`);
    assert.deepEqual([layer.width, layer.height], [640, 480]);
    await page.screenshot({path: path.join(evidence, `gesture-${delegate}.png`)});
  }
  assert.deepEqual(errors, []);
} finally {
  await browser.close();
}

const detectorBrowser = await chromium.launch({channel: 'chromium', args: [
  '--use-fake-device-for-media-stream',
  '--use-file-for-fake-video-capture=' + path.join(repo, 'build/ci-tmp/web-camera.y4m'),
  ...(process.platform === 'linux' ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] : []),
]});
try {
  const context = await detectorBrowser.newContext({viewport: {width: 1280, height: 800}});
  await context.grantPermissions(['camera'], {origin: new URL(base).origin});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.stack));
  await page.goto(base + (base.includes('?') ? '&' : '?') + 'test-hooks');
  for (const task of ['Face Detector', 'Object Detector']) {
    if (task === 'Object Detector') {
      await page.goto(base + (base.includes('?') ? '&' : '?') + 'test-hooks');
    }
    await page.getByRole('button', {name: new RegExp(task)}).click();
    for (const delegate of ['cpu', 'gpu']) {
      await page.getByRole('button', {name: delegate.toUpperCase(), exact: true}).click({timeout: 120000});
      await page.waitForFunction(expected => {
        const video = document.querySelector('video');
        return video?.getAttribute('data-delegate') === expected &&
          Number(video.getAttribute('data-processed-frames')) >= 4 &&
          Number(video.getAttribute('data-detections')) > 0;
      }, delegate, {timeout: 120000});
      const canvas = page.locator('canvas[data-worker-overlay]');
      await canvas.waitFor({timeout: 30000});
      assert.equal(await canvas.count(), 1, `${task} ${delegate} must use one worker overlay`);
      assert.equal(await canvas.evaluate(element => element.style.transform), '',
        `${task} ${delegate} must paint labels upright`);
      await page.screenshot({path: path.join(evidence, `${task.toLowerCase().replaceAll(' ', '-')}-${delegate}.png`)});
    }
  }
  assert.deepEqual(errors, []);
} finally {
  await detectorBrowser.close();
}
console.log(JSON.stringify({status: 'passed', checks: [
  'gesture-cpu-and-gpu-worker-drawing', 'detector-cpu-and-gpu-worker-boxes',
], evidence}));

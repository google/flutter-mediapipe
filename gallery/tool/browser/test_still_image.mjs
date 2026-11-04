import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const base = process.env.GALLERY_WEB_URL || 'http://127.0.0.1:8866/flutter-mediapipe/';
const portrait = path.join(repo, 'packages/mediapipe-task-vision/test/fixtures/face_detection/landmark-ex1.jpg');
const evidence = path.join(repo, 'build/ci-tmp/face-still-image-web');
fs.mkdirSync(evidence, {recursive: true});

const browser = await chromium.launch({channel: 'chromium', headless: true});
try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.goto(base);
  await page.getByRole('button', {name: /Face Landmarker/}).click();
  await page.locator('[flt-semantics-identifier="face-landmarker-mode"]').waitFor();
  await page.getByRole('button', {name: 'Still image', exact: true}).click();
  await page.getByRole('button', {name: 'Choose image'}).waitFor();

  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', {name: 'Choose image'}).click();
  const chooser = await chooserPromise;
  await chooser.setFiles({
    name: 'portrait.jpg',
    mimeType: 'image/jpeg',
    buffer: fs.readFileSync(portrait),
  });
  // The status line under the image reads "portrait.jpg · 1 face detected ·
  // Inference 12.3 ms · GPU".
  await page.getByText(/^portrait\.jpg · 1 face detected · /).waitFor({timeout: 120000});
  assert.deepEqual(errors, []);
  await page.screenshot({path: path.join(evidence, 'result.png')});
  fs.writeFileSync(path.join(evidence, 'report.json'), JSON.stringify({
    platform: 'web',
    checks: ['mode-dropdown', 'file-picker', 'real-image-inference', 'visible-face-result'],
    errors,
  }, null, 2) + '\n');
  console.log('Face Landmarker still image passed in Chromium.');
} finally {
  await browser.close();
}

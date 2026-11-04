import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright';

// The Image Segmenter page as Google's web demo shows it: a smooth mask in the
// legend's colors with the legend under the view, then Output Type set to
// Confidence Mask, which replaces the legend with a class choice.
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const base = process.env.GALLERY_WEB_URL || 'http://127.0.0.1:8866/flutter-mediapipe/';
const portrait = path.join(repo, 'gallery/assets/samples/portrait.jpg');
const evidence = path.join(repo, 'build/ci-tmp/segmenter-display-web');
fs.mkdirSync(evidence, {recursive: true});

const browser = await chromium.launch({channel: 'chromium', headless: true});
try {
  const page = await browser.newPage({viewport: {width: 1280, height: 800}});
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.goto(base);
  await page.getByRole('button', {name: /^Image Segmenter\./}).click();
  await page.locator('[flt-semantics-identifier="image-segmenter-mode"]').waitFor();
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
  await page.getByText(/Segmentation complete · Inference/).waitFor({timeout: 120000});
  await page.getByText('dining table', {exact: true}).waitFor();
  assert.equal(await page.getByRole('button', {name: /DeepLab V3/}).count(), 1);
  assert.equal(await page.getByText(/^Opacity/).count(), 1);
  assert.equal(await page.getByText(/Connections/).count(), 0);
  await page.waitForTimeout(1000);
  await page.screenshot({path: path.join(evidence, 'category.png')});

  await page.getByRole('button', {name: /Category Mask/}).click();
  await page.getByRole('menuitem', {name: 'Confidence Mask', exact: true}).click();
  await page.getByRole('button', {name: /Select Class/}).waitFor({timeout: 120000});
  await page.getByText(/Segmentation complete · Inference/).waitFor({timeout: 120000});
  assert.equal(await page.getByText('dining table', {exact: true}).count(), 0);
  await page.getByRole('button', {name: /Select Class/}).click();
  // The menu builds its 21 classes lazily, so it is scrolled to person.
  const person = page.getByRole('menuitem', {name: 'person', exact: true});
  await page.getByRole('menuitem', {name: 'background', exact: true}).hover();
  for (let i = 0; i < 20 && await person.count() === 0; i++) {
    await page.mouse.wheel(0, 200);
    await page.waitForTimeout(200);
  }
  await person.click();
  await page.getByRole('button', {name: /Select Class person/}).waitFor();
  await page.waitForTimeout(1000);
  await page.screenshot({path: path.join(evidence, 'confidence.png')});

  assert.deepEqual(errors, []);
  console.log('Image Segmenter display passed in Chromium.');
} finally {
  await browser.close();
}

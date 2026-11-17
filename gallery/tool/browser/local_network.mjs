import {execFileSync} from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import https from 'node:https';
import os from 'node:os';
import path from 'node:path';
import {Readable, Transform} from 'node:stream';
import {pipeline} from 'node:stream/promises';
import {fileURLToPath} from 'node:url';

// Keeps a browser test on the machine it runs on. Twice jsDelivr answered the
// runtime's requests with 502 or 503 and no Access-Control-Allow-Origin
// header, on 2026-10-15 (ASSET_HOSTING.md) and on 2026-11-16 (PR #95, run
// 43518618: both Speech browser jobs and Retrieval's macos-15 journey), and a
// worker that cannot read the answer reports only "Failed to fetch" and cannot
// retry. So in every context of a browser that keepLocal wraps:
//
// - Google's runtime, which the packages load from
//   https://cdn.jsdelivr.net/npm/@mediapipe/tasks-<family>@<version>/ unless an
//   app sets MediaPipeWebRuntime.baseUrl (the gallery does not), is answered
//   from the copy tool/ci/web_runtime.py wrote and checked against every
//   family's runtime.json (.github/actions/web-runtime). The page still asks
//   for the URL a deployed gallery asks for, and Playwright's routes see the
//   workers' requests in Chromium, Firefox and WebKit alike, so the same code
//   runs on the same bytes; only the network is gone.
// - A model a family's lib/models.dart pins, as the speech probe's
//   ModelStore download asks for Phonon at its Hugging Face URL, is answered
//   from packages/<family>/models/, where tool/download_models.dart put it,
//   only while the file there still has the pinned SHA-256. A job that
//   downloads no models, as the gallery journeys' web jobs do not, gets the
//   file there the way the Model menus' models below get theirs. It goes
//   through a loopback HTTPS server with a certificate made for the run, which
//   the contexts accept, because Chromium closes the page when a route itself
//   answers with a body as large as Phonon's 87 MB, and a route may only send
//   a request on to a URL of the same scheme.
// - A model the gallery's Model menus offer (gallery/lib/live/task_models.dart),
//   which the page downloads from Google's bucket, goes the same way from
//   gallery/build/task-models/. This script fetches it there first, outside the
//   browser, with three attempts, and keeps it only with its pinned SHA-256.
// - https://invalid.example/ is refused as the test means it to be:
//   web_text_audio_probe.dart's model download that must fail.
// - https://odml.pa.googleapis.com/v1/log is refused: the usage logs Google's
//   runtime posts while a task is open and when it closes
//   (doc/privacy_and_licenses.md). No test reads them, an app's runtime goes
//   on without them, and CI has no business sending them.
// - Any other request off this machine is refused too, and fails the run with
//   its URL: a test that needs it must say so here, and why.
//
// A page under test that is not on this machine, as the check of the deployed
// site is, is left alone.
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
// gallery/tool/web_server.py serves the same folder at /runtime/.
const runtime = path.resolve(repo, process.env.MEDIAPIPE_WEB_RUNTIME_DIR || 'gallery/build/web-runtime');
const runtimeUrl = /^https:\/\/cdn\.jsdelivr\.net\/npm\/(@mediapipe\/tasks-[a-z]+@[^/]+\/.+)$/;
const refused = [/^https:\/\/invalid\.example\//, /^https:\/\/odml\.pa\.googleapis\.com\/v1\/log$/];
const types = {'.mjs': 'text/javascript', '.js': 'text/javascript', '.wasm': 'application/wasm'};
const local = url => ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
const leaks = new Set();
// Every pinned model, by URL: {files, sha256}, read as tool/model_pins.py
// reads `DownloadAsset(url: '...', sha256: '...')`; a model two families pin
// may be in either one's models/.
const models = new Map();
for (const family of fs.readdirSync(path.join(repo, 'packages')).filter(name => name.startsWith('mediapipe-task-'))) {
  const registry = path.join(repo, 'packages', family, 'lib/models.dart');
  if (!fs.existsSync(registry)) continue;
  const literals = expression => [...expression.matchAll(/'([^']*)'/g)].map(match => match[1]).join('');
  for (const [, fields] of fs.readFileSync(registry, 'utf8').matchAll(/DownloadAsset\(([\s\S]*?)\)/g)) {
    const pin = /url:\s*([\s\S]*?),\s*sha256:\s*([\s\S]*?),?\s*$/.exec(fields);
    if (!pin || !literals(pin[1])) continue;
    const url = literals(pin[1]);
    if (!models.has(url)) models.set(url, {files: [], sha256: literals(pin[2])});
    models.get(url).files.push(path.join(repo, 'packages', family, 'models', url.split('/').pop()));
  }
}
// The Model menus' own pins: `TaskModel('<name>', '<path>' ..., '<sha256>', <bytes>)`.
const menuModels = path.join(repo, 'gallery/build/task-models');
for (const [, parts, digest] of fs.readFileSync(path.join(repo, 'gallery/lib/live/task_models.dart'), 'utf8')
  .matchAll(/TaskModel\(\s*'[^']*',\s*((?:'[^']*'\s*)+),\s*'([0-9a-f]{64})'/g)) {
  const url = 'https://storage.googleapis.com/mediapipe-models/' + [...parts.matchAll(/'([^']*)'/g)].map(match => match[1]).join('');
  models.set(url, {files: [path.join(menuModels, digest)], sha256: digest});
}
const sha256 = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const checked = new Map();

// Fetches a pinned model to [file]: three attempts, 10 and 30 seconds apart,
// streamed to disk, since Laya and EmbeddingGemma 2 are 388 to 678 MB.
async function fetchModel(url, file, digest) {
  let failure;
  for (const [attempt, wait] of [[1, 10], [2, 30], [3, 0]]) {
    try {
      const response = await fetch(url, {signal: AbortSignal.timeout(300000)});
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      fs.mkdirSync(path.dirname(file), {recursive: true});
      const hash = crypto.createHash('sha256');
      await pipeline(Readable.fromWeb(response.body), new Transform({
        transform(chunk, encoding, done) {
          hash.update(chunk);
          done(null, chunk);
        },
      }), fs.createWriteStream(`${file}.partial`));
      const got = hash.digest('hex');
      if (got !== digest) throw new Error(`SHA-256 ${got}, pinned ${digest}`);
      fs.renameSync(`${file}.partial`, file);
      checked.set(file, true);
      console.log(`${url}: fetched to ${file}.`);
      return;
    } catch (error) {
      failure = error;
      console.log(`${url}: attempt ${attempt} of 3 failed: ${error.message}`);
      if (wait) await new Promise(resolve => setTimeout(resolve, wait * 1000));
    }
  }
  throw failure;
}
// The verified model files the loopback server sends, by path.
const served = new Map();
let modelServer;

function modelOrigin() {
  modelServer ??= new Promise((resolve, reject) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'local-network-'));
    const [key, cert] = [path.join(dir, 'key.pem'), path.join(dir, 'cert.pem')];
    execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
      '-subj', '/CN=127.0.0.1', '-keyout', key, '-out', cert], {stdio: 'ignore'});
    const server = https.createServer({key: fs.readFileSync(key), cert: fs.readFileSync(cert)}, (request, response) => {
      const file = served.get(request.url);
      if (!file) return response.writeHead(404).end();
      response.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Length': fs.statSync(file).size,
        'Access-Control-Allow-Origin': '*',
      });
      fs.createReadStream(file).pipe(response);
    });
    fs.rmSync(dir, {recursive: true, force: true});
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      server.unref();
      resolve(`https://127.0.0.1:${server.address().port}`);
    });
  });
  return modelServer;
}

function leak(url, why) {
  if (leaks.has(url)) return;
  leaks.add(url);
  console.log(`::error title=A browser test left this machine::${url} (${why})`);
}

process.on('exit', () => {
  if (!leaks.size) return;
  console.error(`Requests that left this machine, all refused:\n  ${[...leaks].join('\n  ')}`);
  process.exitCode = 1;
});

async function answer(route) {
  const url = route.request().url();
  if (refused.some(pattern => pattern.test(url))) return route.abort('addressunreachable');
  const model = models.get(url);
  if (model && !model.files.some(file => fs.existsSync(file))) {
    model.fetching ??= fetchModel(url, model.files[0], model.sha256).catch(error => error);
    const failure = await model.fetching;
    if (failure) {
      leak(url, `could not fetch it to ${model.files[0]}: ${failure.message}`);
      return route.abort('blockedbyclient');
    }
  }
  const modelFile = model?.files.find(file => fs.existsSync(file));
  if (modelFile) {
    if (!checked.has(modelFile)) checked.set(modelFile, sha256(modelFile) === model.sha256);
    if (checked.get(modelFile)) {
      served.set(`/${model.sha256}`, modelFile);
      return route.continue({url: `${await modelOrigin()}/${model.sha256}`});
    }
    leak(url, `${modelFile} does not have the pinned SHA-256`);
    return route.abort('blockedbyclient');
  }
  const file = runtimeUrl.exec(url.split(/[?#]/)[0])?.[1];
  const resolved = file && path.resolve(runtime, decodeURIComponent(file));
  if (resolved?.startsWith(runtime + path.sep) && fs.existsSync(resolved)) {
    return route.fulfill({
      status: 200,
      body: fs.readFileSync(resolved),
      headers: {
        'Content-Type': types[path.extname(resolved)] ?? 'application/octet-stream',
        'Access-Control-Allow-Origin': '*',
        'Cross-Origin-Resource-Policy': 'cross-origin',
      },
    });
  }
  leak(url, file ? `not in the runtime copy at ${runtime}`
    : model ? `not in ${model.files.join(' or ')}` : 'not allowed in gallery/tool/browser/local_network.mjs');
  return route.abort('blockedbyclient');
}

// Applies the rules above to every context [browser] opens from now on, its
// newPage's own included, while [base], the page under test, is on this machine.
export function keepLocal(browser, base) {
  if (!local(new URL(base))) return browser;
  const newContext = browser.newContext.bind(browser);
  browser.newContext = async (options = {}) => {
    // Only the model server's certificate can reach a page: every other
    // request off this machine is answered or refused above.
    const context = await newContext({...options, ignoreHTTPSErrors: true});
    await context.route(url => !local(url) && /^https?:$/.test(url.protocol), answer);
    return context;
  };
  return browser;
}

import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

// Playwright's words for a page or browser that went: "locator.waitFor: Page
// crashed", "locator.click: Target page, context or browser has been closed".
// A failed check, a page's own error and a wait that ran out are not lost pages,
// even when their messages quote these words.
export function isLostPage(error) {
  return !(error instanceof assert.AssertionError) &&
    /^(?:[\w.]+: )?(?:Target page, context or browser has been closed|Target crashed|Page crashed)/
      .test(error?.message ?? '');
}

// What macOS logged about the browser's processes, for a run that lost its
// page: the unified log names a WebKit process that went and why.
export function saveSystemLog(evidence, name) {
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

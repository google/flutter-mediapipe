"""Wait for GitHub Pages to serve this workflow's exact tested source."""
import json
import os
from pathlib import Path
import time
import urllib.request

# The deployed gallery's face pages run vision's pinned browser runtime.
RUNTIME = json.loads((Path(__file__).resolve().parents[2] /
                      'packages/mediapipe-task-vision/assets/runtime.json').read_text())
base = os.environ['PAGE_URL'].rstrip('/') + '/'
expected = os.environ['GITHUB_SHA']
error = None
for attempt in range(20):
    try:
        request = urllib.request.Request(base + 'build-info.json?source=' + expected,
                                         headers={'Cache-Control': 'no-cache'})
        with urllib.request.urlopen(request, timeout=15) as response:
            info = json.load(response)
        if info.get('source_commit') != expected:
            raise RuntimeError(f'Pages still serves {info.get("source_commit")}')
        if info.get('delegate') != 'CPU/WASM' or info['runtime']['version'] != RUNTIME['version']:
            raise RuntimeError('Unexpected deployed delegate or official runtime')
        if info.get('supported_delegates') != ['CPU', 'GPU']:
            raise RuntimeError('Expected both official web delegates')
        print(f'Verified deployed source {expected}: {base}')
        break
    except (OSError, ValueError, RuntimeError, KeyError) as failure:
        error = failure
        print(f'Waiting for Pages ({attempt + 1}/20): {failure}', flush=True)
        if attempt != 19:
            time.sleep(3)
else:
    raise RuntimeError(f'Could not verify deployed source: {error}')

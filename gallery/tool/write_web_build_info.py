"""Record the exact source, official runtime and model in the release artifact."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

repo = Path(__file__).resolve().parents[2]
source = os.environ.get('GITHUB_SHA') or subprocess.check_output(
    ['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
if not re.fullmatch('[0-9a-f]{40}', source):
    raise ValueError('Expected a complete source commit hash')
runtime = json.loads((repo / 'packages/mediapipe-task-vision/assets/runtime.json').read_text())
# `dart run mediapipe_core:bundle_models` names each model by its SHA-256.
bundled = json.loads((repo / 'gallery/assets/mediapipe/manifest.json').read_text())
model = repo / 'gallery/assets/mediapipe' / next(
    entry['file'] for entry in bundled['models']
    if entry['model'] == 'mediapipe_vision: face_landmarker')
info = {
    'source_commit': source,
    'runtime': runtime,
    'model_sha256': hashlib.sha256(model.read_bytes()).hexdigest(),
    'delegate': 'CPU/WASM',
    'supported_delegates': ['CPU', 'GPU'],
    'gpu_backend': 'WebGL 2',
    'ci_url': ('https://github.com/' + os.environ['GITHUB_REPOSITORY'] +
               '/actions/runs/' + os.environ['GITHUB_RUN_ID'])
              if os.environ.get('GITHUB_RUN_ID') else None,
}
output = repo / 'gallery/build/web/build-info.json'
output.write_text(json.dumps(info, indent=2) + '\n')
print(f'Recorded release source {source}')

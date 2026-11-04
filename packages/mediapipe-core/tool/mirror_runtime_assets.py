#!/usr/bin/env python3
"""Inventory reviewed pins, or fill a SHA-named offline source directory.

Runtimes are Google's per-family libraries, as core's `familyRuntimes` pins
them (read through tool/runtime_inventory.dart); models are the families'
pinned models. A runtime's URLs are the member of Google's archive, then the
mirror's file.
"""

import argparse
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import urlsplit

from model_pins import model_pins

ROOT = Path(__file__).resolve().parents[3]
PACKAGES = ROOT / 'packages'
CORE = PACKAGES / 'mediapipe-core'
HEX = re.compile(r'^[0-9a-f]{64}$')


GEMMA_MODELS = {
    'embedding_gemma.task',
    'proofread_quant_200m.litertlm',
    'summarization_quant_200m_2modes.litertlm',
}


def add(items, kind, target, url, digest, label, name=None):
    """Adds a pin. Only an unpublished runtime may have no URL."""
    if (url or kind == 'model') and not url.startswith('https://') \
            or not HEX.fullmatch(digest):
        raise ValueError(f'Unparseable {kind} pin: {label}')
    name = name or urlsplit(url).path.rsplit('/', 1)[-1]
    key = (kind, digest)
    item = items.setdefault(key, {
        'kind': kind, 'sha256': digest, 'urls': [], 'targets': [],
        'release_asset': f'{digest}-{name}', 'license': 'UNKNOWN',
        'pin': label,
    })
    if url and url not in item['urls']:
        item['urls'].append(url)
    for one in target:
        if one not in item['targets']:
            item['targets'].append(one)


def runtime_assets(items):
    inventory = subprocess.run(['dart', 'run', 'tool/runtime_inventory.dart'],
                               cwd=CORE, check=True, capture_output=True,
                               text=True).stdout
    for entry in json.loads(inventory[inventory.index('['):]):
        for url in entry['urls']:
            add(items, 'runtime', [entry['target']], url, entry['sha256'],
                f"familyRuntimes['{entry['family']}']", name=entry['file'])


def model_assets(items):
    for pin in model_pins():
        add(items, 'model', ['all'], pin['url'], pin['sha256'], pin['source'])
    # Runtimes are MediaPipe builds (Apache-2.0, with upstream NOTICE files).
    # Google publishes its MediaPipe task models under Apache-2.0, except the
    # Gemma-based text models, whose Gemma Terms and use-restriction notice
    # must travel with every copy.
    for item in items.values():
        filename = item['release_asset'].split('-', 1)[1]
        item['license'] = ('Gemma Terms' if filename in GEMMA_MODELS
                           else 'Apache-2.0')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', action='append', default=[],
                        help='Build target such as macos/arm64; repeat as needed')
    parser.add_argument('--prefill', type=Path,
                        help='Fill this SHA-named directory using core downloadVerified')
    args = parser.parse_args()
    items = {}
    runtime_assets(items)
    model_assets(items)
    targets = {part for value in args.target for part in value.split(',')}
    selected = [item for item in items.values()
                if not targets or item['kind'] == 'model'
                or targets.intersection(item['targets'])]
    selected.sort(key=lambda item: (item['kind'], item['sha256']))
    if args.prefill:
        if not targets:
            parser.error('--prefill requires at least one --target')
        args.prefill.mkdir(parents=True, exist_ok=True)
        for item in selected:
            if not item['urls']:
                print(f"skipped {item['release_asset']}: not published yet")
        subprocess.run(
            ['dart', 'run', 'tool/prefill_assets.dart', str(args.prefill.resolve())],
            input=json.dumps([item for item in selected if item['urls']]),
            text=True, check=True, cwd=CORE,
        )
    else:
        for item in selected:
            url = item['urls'][0] if item['urls'] else 'unpublished'
            print(f"{item['kind']} {','.join(item['targets'])} {item['sha256']} "
                  f"{item['release_asset']} license={item['license']} url={url}")


if __name__ == '__main__':
    main()

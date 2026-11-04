"""Finds Google's usage-log uploads in an exported WinINet capture trace and
prints what each carried. Usage: wininet_report.py wininet.json"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from telemetry_capture import ENVIRONMENTS, EVENTS, fields, first  # noqa: E402

rows = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig') or '[]')
if isinstance(rows, dict):
    rows = [rows]
print(f'{len(rows)} trace events')
texts, found = [], 0
for row in rows:
    for prop in row.get('props') or []:
        if not isinstance(prop, str):
            continue
        if not prop.startswith('hex:'):
            if 'googleapis' in prop or '/log' in prop:
                texts.append(f"event {row['id']} {row['time']}: {prop[:200]}")
            continue
        data = bytes.fromhex(prop[4:])
        if b'googleapis' in data or b'POST ' in data:
            head = data.split(b'\r\n\r\n')[0][:300]
            texts.append(f"event {row['id']} {row['time']}: {head!r}")
        for start in {0, data.find(b'\r\n\r\n') + 4}:
            body = data[start:]
            try:
                top = fields(body)
            except (ValueError, IndexError):
                continue
            if first(top, 2) != 1786:
                continue
            found += 1
            print(f"\nUpload in event {row['id']} at {row['time']}, {len(body)} bytes, log source 1786")
            for field, event in top:
                if field != 3:
                    continue
                inner = fields(first(fields(event), 6, b''))
                host = fields(first(inner, 1, b''))
                task = fields(first(inner, 2, b''))
                environment = first(host, 6, 0)
                print(f'   {EVENTS.get(first(task, 2, 0), first(task, 2, 0)):17} '
                      f'task {first(task, 1)}, environment {environment} '
                      f'({ENVIRONMENTS.get(environment, "?")}), OS {first(host, 1, 0)}, '
                      f'host_version {first(host, 5, b"").decode("utf-8", "replace")!r}')
print('\nRequest lines and hosts seen:')
for line in texts[:40]:
    print('  ' + line)
print(f'\n{found} uploads decoded')
if not found:
    sys.exit(1)

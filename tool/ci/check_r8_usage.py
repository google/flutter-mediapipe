"""Fails when R8 removed an instance field from this repo's Android plugins.

R8 drops a field that is written but never read. A plugin that keeps memory
alive for native code that way, such as a model buffer Google's SDK reads in
place (UP-033 in upstream-issues.md), loses it in release builds only, and
inference then reads freed memory. Static constants and synthetic references
to an outer class are expected to go, so they pass.

Usage, after a release build:
  python3 -B tool/ci/check_r8_usage.py gallery/build/app/outputs/mapping/release/usage.txt
"""
from pathlib import Path
import sys

PLUGINS = 'dev.mediapipe.flutter.'


def removed_fields(report):
    """The plugins' instance fields that R8's usage report says it removed."""
    fields, owner = [], None
    for line in report.splitlines():
        if not line.strip():
            continue
        if not line[0].isspace():
            owner = line.strip().rstrip(':')
            continue
        member = line.strip()
        if not owner or not owner.startswith(PLUGINS) or '(' in member:
            continue  # another library's code, or a method
        words = member.split()
        if 'static' in words or 'synthetic' in words:
            continue
        fields.append(f'{owner}: {member}')
    return fields


def main(path):
    report = Path(path)
    if not report.is_file():
        print(f'{report} is missing: R8 did not run on this build.')
        return 1
    text = report.read_text(encoding='utf-8')
    if not any(line[:1].isspace() for line in text.splitlines()):
        print(f'{report} lists no removed members; has its format changed?')
        return 1
    fields = removed_fields(text)
    for field in fields:
        print(f'R8 removed {field}')
    if fields:
        print('Hold what native code needs where R8 keeps it, as the plugins '
              'hold model buffers in a map, or delete the field if nothing '
              'needs it.')
        return 1
    print("R8 kept every instance field of the plugins' classes.")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))

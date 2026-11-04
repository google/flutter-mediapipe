"""The families' pinned models, read from each family's `lib/models.dart`.

Maintainer scripts check every model they run against the package's own pin,
so a pin lives in one place. The mirror inventory reads the same table.
"""
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))
from families import PACKAGES, task_families  # noqa: E402

_STRINGS = re.compile(r"'([^']*)'")


def _literals(expression):
    return ''.join(_STRINGS.findall(expression))


def registries():
    """Every family's registry, relative to `packages/`."""
    return [f'{folder}/lib/models.dart' for folder in task_families().values()]


def model_pins():
    """Every pinned model: `{url, sha256, source}`, `source` being the
    registry relative to `packages/`. Every registry pins its models inline,
    as `DownloadAsset(url: '...', sha256: '...')` in its `XModels` class."""
    pins = []
    for relative in registries():
        text = (PACKAGES / relative).read_text()
        for match in re.finditer(r'DownloadAsset\((.*?)\)', text, re.S):
            fields = re.search(r'url:\s*(.*?),\s*sha256:\s*(.*?),?\s*$',
                               match.group(1), re.S)
            if fields and _literals(fields.group(1)):
                pins.append({'url': _literals(fields.group(1)),
                             'sha256': _literals(fields.group(2)),
                             'source': relative})
    return pins


def model_sha256(filename):
    """The pinned SHA-256 of the model Google publishes as [filename]."""
    digests = {pin['sha256'] for pin in model_pins()
               if urlsplit(pin['url']).path.rsplit('/', 1)[-1] == filename}
    if len(digests) != 1:
        raise KeyError(f'{filename} has {len(digests)} pins')
    return digests.pop()

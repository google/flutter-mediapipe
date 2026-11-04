"""Pins Google's per-family libraries to one of its nightly builds.

Google publishes each nightly of its MediaPipe Tasks C libraries in a dated
folder of its bucket, `prebuilts/mediapipe_tasks_c/<YYYYMMDD>/`: an archive of
every family's libraries, headers and notices, with its `BUILD_INFO` beside
it. This moves what a bump moves together:

- core's `familyRuntimes` (lib/src/native_assets/family_runtimes.dart): the
  version, the archive URL, and every pinned file's SHA-256 and size,
  computed as `downloadVerified` checks them: over the archive member,
  inflated, read with HTTP range requests;
- Google's headers (`native/include`, the families' trees merged) and
  `native/BUILD_INFO`, and Google's LICENSE and NOTICE (`third_party/`);
- the sentences that name the pinned build (`SENTENCES`).

    python3 -B packages/mediapipe-core/tool/pin_nightly.py --nightly newest
    python3 -B packages/mediapipe-core/tool/pin_nightly.py --nightly 20261018
    python3 -B packages/mediapipe-core/tool/pin_nightly.py --nightly newest \
        --generation --report build/pin.json

`newest` is the newest complete build: its `BUILD_INFO` names its date and
every family, and its archive holds every file the pins name, with each
family's headers and notices. It prints why it skipped any newer folder.
`--dry-run` reports without writing.

`--generation` pins the archive URL to the generation it hashed
(`...zip?generation=<x-goog-generation>`), which the bucket keeps when the
name is uploaded again; comparison runs of a nightly use it. A build this
project adopts keeps the plain URL, and its files get a mirror release.
`--report` writes what it found as JSON, the C API changes included, even
when it stops.

Nothing is written, and the exit status is non-zero, when the C API changed
beyond comments (the bindings would need regenerating), when the MediaPipe
version changed (tests and docs name it), or when a sentence to update is
missing. Only the archive's directory, the headers and notices and the pinned
members are downloaded (about 300 MB). The mirror release the version names
(`familyRuntimeBaseUrl`) is not posted: until it is, the hooks have only
Google's archive.
"""
import argparse
import datetime
import difflib
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib

CORE = Path(__file__).resolve().parents[1]
REPO = CORE.parents[1]
FAMILY_RUNTIMES = CORE / 'lib/src/native_assets/family_runtimes.dart'
HEADERS = CORE / 'native/include'
BUILD_INFO = CORE / 'native/BUILD_INFO'
NOTICES = CORE / 'third_party'

BUCKET = 'mediapipe-assets'
PREFIX = 'prebuilts/mediapipe_tasks_c/'
LISTING = f'https://storage.googleapis.com/storage/v1/b/{BUCKET}/o'
OBJECTS = f'https://storage.googleapis.com/{BUCKET}/{PREFIX}'

# What one run may download, archive members and directories included.
DOWNLOAD_LIMIT = 4 * 10 ** 9

# The sentences that name the pinned build, by file from the repository root.
# `{long}` is "October 18, 2026", `{day}` "October 18", `{iso}` "2026-10-18"
# and `{stamp}` "20261018"; `{version}` is BUILD_INFO's mediapipe_version, and
# `{generation}` the archive's generation query on a line of its own, if any.
# Each must be in its file, as the current pin renders it. Other mentions of
# a build are its history, or the browser runtime's npm pin, and stay.
SENTENCES = {
    'packages/mediapipe-core/lib/src/native_assets/family_runtimes.dart': [
        'libraries: the {version} nightly build of {long}.',
        "const familyRuntimeVersion = '{version}-nightly.{stamp}';",
        "/// Google's archive of the {long} build, where the hooks download",
        "    'mediapipe_tasks_c/{stamp}/mediapipe_tasks_c_{stamp}.zip{generation}';",
        "/// Every file comes from Google's nightly build of {long}\n"
        '/// (MediaPipe {version}), unmodified.',
    ],
    'packages/mediapipe-core/lib/src/capabilities/task_capabilities.dart': [
        '/// {version} per-family libraries (its nightly build of {long}) on',
    ],
    'packages/mediapipe-core/lib/src/native_assets/reference_wheels.dart': [
        "(`familyRuntimeVersion`, Google's {version} nightly of {day}).",
    ],
    'packages/mediapipe-core/native/README.md': [
        "they come from: MediaPipe {version}, Google's nightly of {iso}.",
    ],
    'packages/mediapipe-core/third_party/README.md': [
        'Google ships with its MediaPipe {version}\nnightly build of {long}',
    ],
    'packages/mediapipe-core/tool/PER_FAMILY_RUNTIMES.md': [
        "pins Google's MediaPipe {version} nightly build of {long}",
        '`https://storage.googleapis.com/mediapipe-assets/prebuilts/'
        'mediapipe_tasks_c/{stamp}/mediapipe_tasks_c_{stamp}.zip`.',
        '`per-family-v{version}-nightly.{stamp}`',
    ],
    'packages/mediapipe-task-decision/README.md': [
        'library (its nightly build of {long})',
    ],
    'packages/mediapipe-task-vision/third_party/README.md': [
        'here from MediaPipe {version}, the\nnightly build of {long}.',
    ],
}


class Fetcher:
    """HTTP GETs with retries, counting what they download."""

    def __init__(self):
        self.downloaded = 0

    def open(self, url, headers=None):
        """The response to a GET of `url`, after up to three attempts on a
        connection error or HTTP 408, 429 or 5xx."""
        for attempt in range(1, 4):
            try:
                request = urllib.request.Request(url, headers=headers or {})
                return urllib.request.urlopen(request, timeout=60)
            except urllib.error.HTTPError as error:
                if error.code not in (408, 429) and error.code < 500 or attempt == 3:
                    raise
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                if attempt == 3:
                    raise
            time.sleep(2 ** attempt)

    def read(self, response):
        data = response.read()
        self.count(len(data))
        return data

    def count(self, size):
        self.downloaded += size
        if self.downloaded > DOWNLOAD_LIMIT:
            raise SystemExit(f'Stopped: over {DOWNLOAD_LIMIT} bytes downloaded.')

    def json(self, url):
        with self.open(url) as response:
            return json.loads(self.read(response))

    def text(self, url):
        """`url`'s body, or None when it is not there."""
        try:
            with self.open(url) as response:
                return self.read(response).decode('utf-8')
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            raise


def listing(fetcher, prefix, delimiter=None):
    """Every object name and subfolder under `prefix` in Google's bucket,
    through every page of the listing."""
    names, folders, token = [], [], None
    while True:
        query = {'prefix': prefix, 'fields': 'items(name),prefixes,nextPageToken'}
        if delimiter:
            query['delimiter'] = delimiter
        if token:
            query['pageToken'] = token
        page = fetcher.json(f'{LISTING}?{urllib.parse.urlencode(query)}')
        names += [item['name'] for item in page.get('items', [])]
        folders += page.get('prefixes', [])
        token = page.get('nextPageToken')
        if not token:
            return names, folders


class Archive:
    """A zip archive on Google's storage, read with HTTP range requests. Every
    request names the archive's ETag (If-Range), so a replaced archive fails
    instead of mixing two builds."""

    def __init__(self, fetcher, url):
        self.fetcher, self.url = fetcher, url
        # The end of central directory record, its comment of up to 64 KiB,
        # and the Zip64 locator and record before it, as downloadVerified reads.
        with fetcher.open(url, {'Range': 'bytes=-65633'}) as response:
            self.etag = response.headers['ETag']
            self.generation = response.headers.get('x-goog-generation')
            tail_start, _, self.size = self._range(response)
            tail = fetcher.read(response)
        self.entries = self._directory(tail, tail_start)

    def _range(self, response):
        match = re.fullmatch(r'bytes (\d+)-(\d+)/(\d+)',
                             response.headers.get('Content-Range', ''))
        if response.status != 206 or not match:
            raise SystemExit(f'{self.url}: no range in the response; the host '
                             'ignored it or the archive changed')
        return tuple(int(group) for group in match.groups())

    def bytes(self, first, last):
        with self.fetcher.open(self.url, {'Range': f'bytes={first}-{last}',
                                          'If-Range': self.etag}) as response:
            if self._range(response)[:2] != (first, last):
                raise SystemExit(f'{self.url}: wrong range for {first}-{last}')
            return self.fetcher.read(response)

    def _directory(self, tail, tail_start):
        at = tail.rfind(b'PK\x05\x06')
        if at < 0:
            raise SystemExit(f'{self.url}: no zip central directory')
        size, offset = struct.unpack_from('<II', tail, at + 12)
        if 0xffffffff in (size, offset):
            record = struct.unpack_from('<Q', tail, at - 20 + 8)[0] - tail_start
            if tail[at - 20:at - 16] != b'PK\x06\x07' or \
                    tail[record:record + 4] != b'PK\x06\x06':
                raise SystemExit(f'{self.url}: no Zip64 directory record')
            size, offset = struct.unpack_from('<QQ', tail, record + 40)
        listing = (tail[offset - tail_start:offset - tail_start + size]
                   if offset >= tail_start else self.bytes(offset, offset + size - 1))
        entries, at = {}, 0
        while listing[at:at + 4] == b'PK\x01\x02':
            flags, method = struct.unpack_from('<HH', listing, at + 8)
            crc, compressed, inflated = struct.unpack_from('<III', listing, at + 16)
            name_length, extra_length, comment_length = struct.unpack_from(
                '<HHH', listing, at + 28)
            local = struct.unpack_from('<I', listing, at + 42)[0]
            name = listing[at + 46:at + 46 + name_length].decode('utf-8')
            extra = at + 46 + name_length
            while extra + 4 <= at + 46 + name_length + extra_length:
                kind, length = struct.unpack_from('<HH', listing, extra)
                if kind == 1:
                    values = iter(struct.unpack_from(f'<{length // 8}Q', listing, extra + 4))
                    if inflated == 0xffffffff:
                        inflated = next(values)
                    if compressed == 0xffffffff:
                        compressed = next(values)
                    if local == 0xffffffff:
                        local = next(values)
                extra += 4 + length
            entries[name] = {'flags': flags, 'method': method, 'crc': crc,
                             'compressed': compressed, 'size': inflated,
                             'offset': local}
            at += 46 + name_length + extra_length + comment_length
        if not entries:
            raise SystemExit(f'{self.url}: empty zip central directory')
        return entries

    def member(self, name, sink):
        """Feeds member `name`, inflated, to `sink` in chunks; fails unless its
        size and CRC-32 match the directory."""
        entry = self.entries[name]
        if entry['flags'] & 1 or entry['method'] not in (0, 8):
            raise SystemExit(f'{self.url}: {name} is encrypted or uses method '
                             f"{entry['method']}")
        header = self.bytes(entry['offset'], entry['offset'] + 29)
        if header[:4] != b'PK\x03\x04':
            raise SystemExit(f'{self.url}: no local header for {name}')
        start = entry['offset'] + 30 + sum(struct.unpack_from('<HH', header, 26))
        inflater = zlib.decompressobj(-15) if entry['method'] == 8 else None
        size = crc = 0

        def feed(chunk):
            nonlocal size, crc
            size += len(chunk)
            crc = zlib.crc32(chunk, crc)
            sink(chunk)

        if entry['compressed']:
            last = start + entry['compressed'] - 1
            with self.fetcher.open(self.url, {'Range': f'bytes={start}-{last}',
                                              'If-Range': self.etag}) as response:
                if self._range(response)[:2] != (start, last):
                    raise SystemExit(f'{self.url}: wrong range for {name}')
                while chunk := response.read(1 << 20):
                    self.fetcher.count(len(chunk))
                    feed(inflater.decompress(chunk) if inflater else chunk)
        if inflater:
            feed(inflater.flush())
        if size != entry['size'] or crc != entry['crc']:
            raise SystemExit(f'{self.url}: {name} inflated to {size} bytes, '
                             f"CRC {crc:08x}; its directory says {entry['size']}, "
                             f"{entry['crc']:08x}")

    def read(self, name):
        chunks = []
        self.member(name, chunks.append)
        return b''.join(chunks)

    def digest(self, name):
        """SHA-256 and size of member `name`, as `downloadVerified` checks it."""
        hasher = hashlib.sha256()
        self.member(name, hasher.update)
        return hasher.hexdigest(), self.entries[name]['size']


def current_pins():
    """The current pin: `{'stamp', 'version', 'generation', 'paths'}` from
    `familyRuntimes`, `paths` in source order and `generation` None for the
    plain archive URL."""
    source = FAMILY_RUNTIMES.read_text(encoding='utf-8')
    version, stamp = re.search(
        r"^const familyRuntimeVersion = '([^']+)-nightly\.(\d{8})';", source, re.M).groups()
    generation = re.search(r"\.zip'\n\s*'\?generation=(\d+)';", source)
    paths = re.findall(r"FamilyRuntime\(\s*'([^']+)',\s*'[0-9a-f]{64}',\s*\d+,\s*\)", source)
    if len(paths) != source.count(': FamilyRuntime(\n'):
        raise SystemExit(f'{FAMILY_RUNTIMES}: a FamilyRuntime entry is not parseable')
    return {'stamp': stamp, 'version': version, 'paths': paths,
            'generation': generation and generation.group(1)}


def parse_build_info(text):
    return dict(line.split('=', 1) for line in text.splitlines() if '=' in line)


def families(paths):
    return sorted({path.split('/', 1)[0] for path in paths})


def check_build(fetcher, stamp, paths):
    """Build `stamp`'s `(build_info_text, archive)`, or the reason it is not
    complete."""
    names, _ = listing(fetcher, f'{PREFIX}{stamp}/')
    names = {name[len(PREFIX) + len(stamp) + 1:] for name in names}
    if 'BUILD_INFO' not in names:
        return 'no BUILD_INFO'
    zip_name = f'mediapipe_tasks_c_{stamp}.zip'
    if zip_name not in names:
        return f'no {zip_name}'
    text = fetcher.text(f'{OBJECTS}{stamp}/BUILD_INFO')
    info = parse_build_info(text or '')
    if info.get('build_date') != stamp or not info.get('mediapipe_version'):
        return f'BUILD_INFO does not name build_date={stamp} and a mediapipe_version'
    missing = set(families(paths)) - set(info.get('domains', '').split())
    if missing:
        return f"BUILD_INFO's domains lack {sorted(missing)}"
    try:
        archive = Archive(fetcher, f'{OBJECTS}{stamp}/{zip_name}')
    except (SystemExit, urllib.error.URLError, struct.error) as error:
        return f'archive not readable: {error}'
    needed = [*paths, 'BUILD_INFO']
    for family in families(paths):
        needed += [f'{family}/LICENSE', f'{family}/NOTICE']
        if not any(name.startswith(f'{family}/include/') and name.endswith('.h')
                   for name in archive.entries):
            return f'the archive has no {family}/include headers'
    absent = [name for name in needed if name not in archive.entries]
    if absent:
        return f'the archive lacks {absent}'
    return text, archive


def pick_build(fetcher, requested, paths):
    """The `(stamp, build_info_text, archive)` to pin."""
    _, folders = listing(fetcher, PREFIX, '/')
    stamps = sorted((folder[len(PREFIX):].rstrip('/') for folder in folders
                     if re.fullmatch(r'\d{8}/', folder[len(PREFIX):])), reverse=True)
    print(f"Google's nightly folders: {', '.join(reversed(stamps))}")
    candidates = stamps if requested == 'newest' else [requested]
    if requested != 'newest' and requested not in stamps:
        raise SystemExit(f'No folder {PREFIX}{requested}/ in {BUCKET}.')
    for stamp in candidates:
        result = check_build(fetcher, stamp, paths)
        if isinstance(result, str):
            print(f'Skipped {stamp}: {result}')
            continue
        return (stamp, *result)
    raise SystemExit('No complete build.')


def strip_comments(source):
    """C source without its comments and with whitespace collapsed: what the
    compiler, and so the ABI, sees."""
    source = re.sub(r'/\*.*?\*/|//[^\n]*', ' ', source, flags=re.S)
    return ' '.join(source.split())


def headers(archive, names):
    """The families' header trees merged, `{relative path: bytes}`: a header
    several families ship must be identical in each."""
    merged = {}
    for name in sorted(names):
        rest = name.partition('/')[2]
        if not rest.startswith('include/') or name.endswith('/'):
            continue
        relative, data = rest[len('include/'):], archive.read(name)
        if merged.setdefault(relative, data) != data:
            raise SystemExit(f'{relative} differs between families in the archive')
    return merged


def compare_headers(new):
    """Prints how `new` differs from `native/include`; returns the API
    changes (beyond comments), one line each."""
    old = {str(path.relative_to(HEADERS)): path.read_bytes()
           for path in HEADERS.rglob('*') if path.is_file()}
    changes = [f'added {name}' for name in sorted(set(new) - set(old))]
    changes += [f'removed {name}' for name in sorted(set(old) - set(new))]
    comment_only = []
    for name in sorted(set(old) & set(new)):
        if old[name] == new[name]:
            continue
        before, after = old[name].decode('utf-8'), new[name].decode('utf-8')
        if strip_comments(before) != strip_comments(after):
            changes.append(f'changed {name}')
        else:
            comment_only.append(name)
        for line in difflib.unified_diff(before.splitlines(), after.splitlines(),
                                         f'a/{name}', f'b/{name}', n=0, lineterm=''):
            print(f'    {line}')
    same = sum(1 for name in set(old) & set(new) if old[name] == new[name])
    print(f'Headers: {len(new)} merged; {same} identical, {len(comment_only)} '
          f'changed in comments only, {len(changes)} API changes.')
    return changes, comment_only


def render(template, stamp, version, generation=None):
    date = datetime.date(int(stamp[:4]), int(stamp[4:6]), int(stamp[6:]))
    day = f'{date:%B} {date.day}'
    query = f"'\n    '?generation={generation}" if generation else ''
    return template.format(long=f'{day}, {date.year}', day=day, iso=date.isoformat(),
                           stamp=stamp, version=version, generation=query)


def rewritten_sources(old, stamp, version, generation, digests):
    """`{path: new text}` for every file `SENTENCES` names, with the pins in
    `family_runtimes.dart` replaced by `digests`."""
    texts, problems = {}, []
    for relative, templates in SENTENCES.items():
        text = (REPO / relative).read_text(encoding='utf-8')
        for template in templates:
            before = render(template, old['stamp'], old['version'], old['generation'])
            after = render(template, stamp, version, generation)
            if before not in text:
                problems.append(f'{relative}: no "{before}"')
            text = text.replace(before, after)
        texts[relative] = text
    if problems:
        raise SystemExit('Update SENTENCES in this tool; not found:\n  ' +
                         '\n  '.join(problems))
    relative = str(FAMILY_RUNTIMES.relative_to(REPO))

    def pin(match):
        sha256, size = digests[match.group(2)]
        return f"{match.group(1)}'{sha256}',\n{match.group(3)}{size},"

    texts[relative] = re.sub(
        r"(FamilyRuntime\(\n\s*'([^']+)',\n\s*)'[0-9a-f]{64}',\n(\s*)\d+,",
        pin, texts[relative])
    return texts


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--nightly', required=True,
                        help='a build folder, YYYYMMDD, or newest')
    parser.add_argument('--dry-run', action='store_true',
                        help='report what would change without writing')
    parser.add_argument('--generation', action='store_true',
                        help='pin the archive URL to the generation hashed')
    parser.add_argument('--report', type=Path,
                        help='write what was found to this JSON file')
    args = parser.parse_args()
    if args.nightly != 'newest' and not re.fullmatch(r'\d{8}', args.nightly):
        parser.error('--nightly takes YYYYMMDD or newest')
    old = current_pins()
    fetcher = Fetcher()
    stamp, info_text, archive = pick_build(fetcher, args.nightly, old['paths'])
    info = parse_build_info(info_text)
    report = {'nightly': stamp, 'previous': old['stamp'], 'build_info': info,
              'archive': archive.url, 'generation': archive.generation,
              'api_changes': None, 'comment_only_headers': None,
              'notices_changed': [], 'written': False}

    def write_report():
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

    print(f"Pinning {stamp}: MediaPipe {info['mediapipe_version']}, Kokoro build "
          f"{info.get('kokoro_build_number')}, changelist {info.get('piper_changelist')}; "
          f'archive {archive.size} bytes, generation {archive.generation}.')
    if info['mediapipe_version'] != old['version']:
        write_report()
        raise SystemExit(f"MediaPipe {info['mediapipe_version']} replaces "
                         f"{old['version']}: the tests and docs name the version, so "
                         'move it by hand.')
    build_info = archive.read('BUILD_INFO')
    if build_info.decode('utf-8') != info_text:
        raise SystemExit("The archive's BUILD_INFO is not the one beside it.")

    new_headers = headers(archive, archive.entries)
    changes, comment_only = compare_headers(new_headers)
    report['api_changes'], report['comment_only_headers'] = changes, comment_only
    if changes:
        write_report()
        raise SystemExit('The C API changed, so the bindings need regenerating '
                         '(make generate); nothing written:\n  ' + '\n  '.join(changes))
    notices = {}
    for name in ('LICENSE', 'NOTICE'):
        copies = {archive.read(f'{family}/{name}') for family in families(old['paths'])}
        if len(copies) != 1:
            raise SystemExit(f'The families ship different {name} files.')
        notices[name] = copies.pop()
        vendored = (NOTICES / name).read_bytes()
        if notices[name] != vendored:
            report['notices_changed'].append(name)
            print(f'{name} changed: {len(vendored)} -> {len(notices[name])} bytes; '
                  'third_party/README.md may describe the old one.')

    digests = {}
    for path in old['paths']:
        digests[path] = archive.digest(path)
        print(f'  {digests[path][0]} {digests[path][1]:>9} {path}')
    generation = archive.generation if args.generation else None
    if args.generation and not generation:
        raise SystemExit(f'{archive.url}: no x-goog-generation header to pin.')
    texts = rewritten_sources(old, stamp, old['version'], generation, digests)
    changed = [relative for relative, text in texts.items()
               if (REPO / relative).read_text(encoding='utf-8') != text]
    print(f'Downloaded {fetcher.downloaded} bytes.')
    if args.dry_run:
        write_report()
        print(f'Would rewrite {len(changed)} files; dry run, nothing written.')
        return
    for relative in changed:
        (REPO / relative).write_text(texts[relative], encoding='utf-8')
    for name, data in new_headers.items():
        target = HEADERS / name
        if not target.exists() or target.read_bytes() != data:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    BUILD_INFO.write_bytes(build_info)
    for name, data in notices.items():
        (NOTICES / name).write_bytes(data)
    for relative in changed:
        for number, line in enumerate(texts[relative].splitlines(), 1):
            if relative.endswith('.dart') and len(line) > 80:
                print(f'{relative}:{number} is {len(line)} columns: rewrap it.')
    if stamp != old['stamp']:
        print(f"Still naming the {old['stamp']} build (its history, or the browser "
              'runtime, which this does not move):', flush=True)
        mentions = {render(form, old['stamp'], old['version'])
                    for form in ('{stamp}', '{iso}', '{day}')}
        patterns = [part for mention in sorted(mentions) for part in ('-e', mention)]
        subprocess.run(['git', 'grep', '-n', '-F', *patterns, '--', '.', ':!*.h',
                        f':!{Path(__file__).resolve().relative_to(REPO)}'], cwd=REPO)
    report['written'] = True
    write_report()
    print(f'Pinned {stamp}. Then: git diff --stat, and the checks in CONTRIBUTING.md.')


if __name__ == '__main__':
    main()

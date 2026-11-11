"""Writes samples/README.md, the index of the docs' samples: per task, which
modes have a sample, the other samples, the platforms the task runs on (from
tool/coverage/matrix.json) and the docs that show each file.

    python3 -B tool/samples_index.py

tool/check_docs.py fails when samples/README.md differs from what this
writes.
"""
import json
from pathlib import Path
import re

from check_docs import DOCS, REPO, SAMPLES, sample_blocks, sample_files

FAMILIES = ['vision', 'audio', 'text', 'retrieval', 'decision', 'core']
# The modes a task's API offers, in order. A mode without a file shows as a
# gap; tasks not listed have no modes, only named samples.
MODES = {
    **{task: ['image', 'video', 'live_stream'] for task in [
        'face_detector', 'face_landmarker', 'gesture_recognizer',
        'hand_landmarker', 'holistic_landmarker', 'image_classifier',
        'image_embedder', 'image_segmenter', 'object_detector',
        'pose_landmarker']},
    'interactive_segmenter': ['image'],
    'audio_classifier': ['clip', 'stream'],
    'audio_transcriber': ['clip', 'stream'],
    'text_to_speech': ['utterance', 'stream'],
    'universal_embedder': ['text', 'image', 'audio'],
    'semantic_retriever': ['text', 'image', 'audio_and_content'],
    'decision_maker': ['single', 'batch'],
}
PLATFORMS = {'web': 'Web', 'android': 'Android', 'ios': 'iOS',
             'macos': 'macOS', 'linux': 'Linux', 'windows': 'Windows'}
# Samples that run another model than their folder's task usually does, and
# the coverage matrix row that model has.
MODEL_ROWS = {'TextModels.embeddingGemma': 'embedding_gemma'}
WEB_ONLY = re.compile(r"^import '(dart:js_interop|package:web/)", re.M)


def platforms(cells):
    """`CPU`, `CPU, GPU` or `no` for each platform of a matrix row."""
    def runs(value):
        return value in ('required', 'device')

    row = []
    for key in PLATFORMS:
        cell = cells[key]
        if not runs(cell['cpu']):
            row.append('no')
        elif runs(cell.get('gpu', '')):
            row.append('CPU, GPU')
        elif cell.get('gpu', '').startswith('pending'):
            row.append('CPU (GPU planned)')
        else:
            row.append('CPU')
    return row


def render():
    matrix = json.loads((REPO / 'tool/coverage/matrix.json').read_text())
    cells = matrix['cells']
    docs = {}
    for doc in DOCS:
        for _, path, _ in sample_blocks(doc):
            if path and doc not in docs.setdefault(path, []):
                docs[path].append(doc)
    files = sample_files()
    lines = [
        '# Samples',
        '',
        '<!-- Written by tool/samples_index.py; do not edit. -->',
        '',
        'Every Dart sample in the docs, one file per sample. Each file is the',
        "doc's code block byte for byte: change both together, then run",
        '`python3 -B tool/samples_index.py` and `python3 -B tool/check_docs.py`',
        '(it fails, naming the doc and line, on any difference).',
        '',
        'A dash in Modes is a mode the task offers that has no sample yet.',
        'Platforms come from the coverage matrix (`tool/coverage/matrix.json`).',
        'The runnable object detection app is in',
        '[apps/object_detection](apps/object_detection/).',
    ]
    for family in FAMILIES:
        tasks = {}
        for path in files:
            parts = Path(path).relative_to('samples').parts
            if parts[0] == family:
                tasks.setdefault(parts[1], []).append(path)
        lines += ['', f'## {family}', '',
                  '| Task | Modes | Other samples | '
                  + ' | '.join(PLATFORMS.values()) + ' |',
                  '|' + ' --- |' * (3 + len(PLATFORMS))]
        for task, paths in sorted(tasks.items()):
            groups = {task: paths}
            for marker, row in MODEL_ROWS.items() if task in cells else ():
                moved = [path for path in paths
                         if marker in (REPO / path).read_text()]
                if moved:
                    groups[task] = [p for p in paths if p not in moved]
                    groups[row] = moved
            for row, group in groups.items():
                lines.append(table_row(task, row, group, cells))
    lines += ['', '## Where each sample appears', '',
              '| Sample | Docs |', '| --- | --- |']
    for path in files:
        shown = ', '.join(f'[{doc}](../{doc})' for doc in docs.get(path, []))
        lines.append(f'| [{path[len("samples/"):]}]({path[len("samples/"):]}) '
                     f'| {shown} |')
    return '\n'.join(lines) + '\n'


def folder(path, task):
    return Path('samples', Path(path).parts[1], task)


def table_row(task, row, paths, cells):
    def link(path):
        name = Path(path).relative_to(folder(path, task))
        text = name.with_suffix('').as_posix()
        if WEB_ONLY.search((REPO / path).read_text()):
            text += ' (web only)'
        return f'[{text}]({path[len("samples/"):]})'

    modes = MODES.get(task, []) if row == task else []
    stems = {Path(path).stem: path for path in paths}
    shown = [link(stems[mode]) if mode in stems else f'{mode}: -'
             for mode in modes]
    others = [link(path) for path in paths
              if Path(path).relative_to(folder(path, task))
              .with_suffix('').as_posix() not in modes]
    name = task if row == task else f'{task} ({row} model)'
    support = platforms(cells[row]) if row in cells else [''] * len(PLATFORMS)
    return (f'| {name} | {", ".join(shown)} | {", ".join(others)} | '
            + ' | '.join(support) + ' |')


def main():
    (SAMPLES / 'README.md').write_text(render())


if __name__ == '__main__':
    main()

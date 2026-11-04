"""Checks what must agree across the packages but cannot be derived.

Tools find the task families on disk (packages/mediapipe-core/tool/families.py),
so a new family reaches them. This checks the rest:

- **Lists by family:** the README's support table (a row per family, and a ✓
  wherever the coverage matrix has a cell that is not unsupported),
  CONTRIBUTING's first release, core's bundlable and web runtime families,
  each family's Makefile targets and coverage-matrix test, and the
  bundled-models test's subset.
- **Pins that move together:** the packages' versions and SDK and Flutter
  constraints; each family's browser runtime version against its
  `assets/runtime.json`; the Flutter version in the docs against CI's; and
  models two families pin, which must be identical so apps download them once;
  and the browser alignment oracle's tolerances against the Dart oracle's.

    python3 -B tool/check_repository.py

Exit status is non-zero, with every problem listed, unless all of it holds.
"""
import json
from pathlib import Path
import re
import sys

REPO = Path(__file__).resolve().parents[1]
CORE_TOOL = REPO / 'packages/mediapipe-core/tool'
sys.path.insert(0, str(CORE_TOOL))
from families import CORE, PACKAGES, package_folders, task_families  # noqa: E402
from model_pins import model_pins, registries  # noqa: E402
import test_bundled_models  # noqa: E402

# The two alignment oracles, which apply one criterion in Dart and JavaScript.
ALIGNMENT_ORACLES = ['gallery/integration_test/support/alignment_oracle.dart',
                     'gallery/tool/browser/test_browser.mjs']

# Where the docs name the Flutter version CI runs.
FLUTTER_DOCS = ['README.md', 'gallery/tool/WEB_FACE.md',
                'packages/mediapipe-task-vision/README.md']

# The README's "Where it runs" rows and the coverage-matrix tasks each stands
# for; together they must cover the matrix.
README_ROWS = {
    'Vision': ['face_detector', 'face_landmarker', 'gesture_recognizer',
               'hand_landmarker', 'holistic_landmarker', 'image_classifier',
               'image_embedder', 'image_segmenter', 'interactive_segmenter',
               'object_detector', 'pose_landmarker'],
    'Text (classify, embed, detect language)': ['language_detector', 'text_classifier',
                                                'text_embedder'],
    'Text (EmbeddingGemma)': ['embedding_gemma'],
    'Text (proofread, summarize)': ['text_proofreader', 'text_summarizer'],
    'Audio': ['audio_classifier'],
    'Decision': ['decision_maker'],
    'Retrieval': ['semantic_retriever', 'universal_embedder'],
}


def read(relative):
    return (REPO / relative).read_text(encoding='utf-8')


def family_lists(problems):
    families = task_families()
    readme = read('README.md')
    table = readme[readme.index('## Where it runs'):]
    for family in families:
        if not re.search(r'^\| ' + family.capitalize() + r'\b', table, re.M):
            problems.append(f'README.md: "Where it runs" has no {family} row')
    contributing = read('CONTRIBUTING.md')
    release = contributing[contributing.index('## Versions and the first release'):]
    release = release[:release.index('\n## ', 1)]
    for family in families:
        if f'mediapipe_{family}' not in release:
            problems.append(f'CONTRIBUTING.md: the first release does not name mediapipe_{family}')
    # bin/web_runtime.dart reads the same table.
    source = 'packages/mediapipe-core/lib/src/model_bundler.dart'
    text = read(source)
    block = text[text.index('const bundlableFamilies = {'):]
    listed = set(re.findall(r"'mediapipe_(\w+)'", block[:block.index(';')]))
    if listed != set(families):
        problems.append(f'{source}: lists {sorted(listed)}, not {sorted(families)}')
    makefile = read('Makefile')
    for family in families:
        for target in (f'models_{family}', f'test_{family}'):
            if not re.search(r'^' + target + r':', makefile, re.M):
                problems.append(f'Makefile: no {target} target')
    owners = {}
    for family, folder in families.items():
        test = PACKAGES / folder / 'test/coverage_matrix_test.dart'
        if not test.is_file():
            problems.append(f'packages/{folder}: no test/coverage_matrix_test.dart')
            continue
        for task in re.findall(r"^  '(\w+)':", test.read_text(encoding='utf-8'), re.M):
            owners.setdefault(task, []).append(family)
    cells = json.loads(read('tool/coverage/matrix.json'))['cells']
    for task in cells:
        if len(owners.get(task, [])) != 1:
            problems.append(f'tool/coverage/matrix.json: {task} is checked by '
                            f'{owners.get(task, [])}, not one family')
    where_it_runs(problems, table, cells)
    bundled = sorted(folder for folder, _ in test_bundled_models.FAMILIES.values())
    if bundled != sorted(families.values()):
        problems.append(f'test_bundled_models.py: FAMILIES covers {bundled}')


def where_it_runs(problems, table, cells):
    """The README's ✓ cells: one wherever a row's task has a matrix cell, on
    either delegate, that is not unsupported (pending cells count: the package
    claims them)."""
    lines = table.splitlines()
    first = next(i for i, line in enumerate(lines) if line.startswith('| Family'))
    rows = []
    for line in lines[first:]:
        if not line.startswith('|'):
            break
        rows.append([cell.strip() for cell in line.strip().strip('|').split('|')])
    platforms = [column.split()[0].lower() for column in rows[0][1:]]
    found = {row[0]: dict(zip(platforms, row[1:])) for row in rows[2:]}
    listed = sorted(task for tasks in README_ROWS.values() for task in tasks)
    if listed != sorted(cells):
        problems.append(f'check_repository.py: README_ROWS covers {listed}, '
                        f'tool/coverage/matrix.json has {sorted(cells)}')
    for row, tasks in README_ROWS.items():
        if row not in found:
            problems.append(f'README.md: "Where it runs" has no "{row}" row')
            continue
        for platform in platforms:
            runs = any(not cells[task][platform][delegate].startswith('unsupported')
                       for task in tasks if task in cells for delegate in ('cpu', 'gpu'))
            mark = found[row].get(platform, '')
            if (mark == '✓') != runs:
                problems.append(f'README.md: "Where it runs" {row} / {platform} is '
                                f'"{mark}", the matrix says {"✓" if runs else "blank"}')


def pubspec_pins(problems):
    def pins(folder):
        text = (PACKAGES / folder / 'pubspec.yaml').read_text(encoding='utf-8')
        return {key: re.search(pattern, text, re.M).group(1) for key, pattern in {
            'version': r'^version: (\S+)$',
            'sdk': r'^  sdk: (\S+)$',
            'flutter': r"^  flutter: '(\S+)'$",
        }.items()}
    core = pins(CORE)
    for folder in package_folders()[1:]:
        for key, value in pins(folder).items():
            if value != core[key]:
                problems.append(f'packages/{folder}/pubspec.yaml: {key} {value}, '
                                f'core has {core[key]}')


def runtime_versions(problems):
    # Families without their own browser constant (`_browserRuntimeVersion`)
    # report core's tasksRuntimeVersionOn.
    core = read('packages/mediapipe-core/lib/src/capabilities/task_capabilities.dart')
    web = re.search(r"operatingSystem == 'web' \? '([^']+)'", core).group(1)
    for family, folder in task_families().items():
        capabilities = (PACKAGES / folder / 'lib/src/capabilities.dart').read_text(
            encoding='utf-8')
        own = re.search(r"^const \w+RuntimeVersion = '([^']+)';", capabilities, re.M)
        claimed = own.group(1) if own else web
        pinned = json.loads((PACKAGES / folder / 'assets/runtime.json').read_text())['version']
        if claimed != pinned:
            problems.append(f'{family}: capabilities report browser runtime {claimed}, '
                            f'assets/runtime.json pins {pinned}')


def flutter_versions(problems):
    ci = {}
    github = REPO / '.github'
    for source in sorted([*github.glob('workflows/*.y*ml'), *github.glob('actions/*/action.yml')]):
        for version in re.findall(r"flutter-version: '([^']+)'", source.read_text()):
            ci.setdefault(version, []).append(str(source.relative_to(github)))
    if len(ci) != 1:
        problems.append(f'.github: Flutter versions differ: {ci}')
        return
    version = next(iter(ci))
    for doc in FLUTTER_DOCS:
        for found in re.findall(r'Flutter[ -]\**(\d+\.\d+\.\d+)', read(doc)):
            if found != version:
                problems.append(f'{doc}: Flutter {found}, CI runs {version}')


def shared_models(problems):
    # The same file in two registries must be the same pin.
    by_file = {}
    for pin in model_pins():
        by_file.setdefault(pin['url'].rsplit('/', 1)[-1], []).append(pin)
    for name, pins in by_file.items():
        if len({(pin['url'], pin['sha256']) for pin in pins}) != 1:
            sources = sorted(pin['source'] for pin in pins)
            problems.append(f'{name}: pinned differently in {sources}')
    # A name two families list must be the same model (the bundled-models
    # test relies on it).
    resolved = {}
    for relative in registries():
        text = (PACKAGES / relative).read_text(encoding='utf-8')
        block = text[text.index('static const byName'):]
        block = block[:block.index('};')]
        for name, constant in re.findall(r"'(\w+)': (\w+)", block):
            asset = re.search(r'static const ' + constant + r' = DownloadAsset\((.*?)\);',
                              text, re.S)
            resolved.setdefault(name, {})[relative] = asset and ' '.join(asset.group(1).split())
    for name, assets in resolved.items():
        if len(assets) > 1 and (None in assets.values() or len(set(assets.values())) != 1):
            problems.append(f'{name}: listed by {sorted(assets)} but not the same inline pin')


def alignment_tolerances(problems):
    values = {}
    for source in ALIGNMENT_ORACLES:
        for name, value in re.findall(r'^const (alignment\w*Tolerance) = ([\d.]+);',
                                      read(source), re.M):
            values.setdefault(name, {})[source] = value
    for name, found in values.items():
        if len(found) != len(ALIGNMENT_ORACLES) or len(set(found.values())) != 1:
            problems.append(f'{name}: the alignment oracles disagree: {found}')


def main():
    problems = []
    for check in (family_lists, pubspec_pins, runtime_versions, flutter_versions,
                  shared_models, alignment_tolerances):
        check(problems)
    for problem in problems:
        print(problem)
    print(f'{len(task_families())} task families; '
          f'{len(problems)} problem{"" if len(problems) == 1 else "s"}.')
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()

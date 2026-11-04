"""Checks the user-facing docs: Dart samples compile, relative links resolve
and the model names their pubspec samples list exist.

Every ```dart block that has an `import` is a complete sample: each becomes a
library in a scratch Flutter app that depends on every package by path,
and `flutter analyze` must report nothing. Samples must also work in
browsers: the app builds for the web with every sample imported, and since
that build accepts `dart:io` and `dart:isolate` (they fail only at run time),
a sample importing either fails outright. Blocks without imports are
fragments and are skipped. Relative Markdown links must point at files that
exist in the repository. Every name under `hooks.user_defines.<family>.models`
must be a key of that family's `byName`.
"""
import argparse
import functools
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'packages/mediapipe-core/tool'))
from families import PACKAGES, package_folders, package_name, task_families  # noqa: E402

DOCS = [
    'README.md', 'MIGRATION.md', 'CONTRIBUTING.md',
    'doc/platform_setup.md', 'doc/privacy_and_licenses.md',
    'doc/guides/vision/object_detector.md',
    *(f'packages/{folder}/README.md' for folder in package_folders()),
]
BLOCK = re.compile(r'^```dart\n(.*?)^```', re.S | re.M)
LINK = re.compile(r'\]\(([^)\s]+)\)')
REPOSITORY = re.compile(
    r'https://github\.com/google/flutter-mediapipe/(?:blob|tree)/main/'
    r'([^?\s]+)')
MODELS = re.compile(r'^\s*mediapipe_(\w+):\n\s*models: \[([^\]]*)\]', re.M)
# The web build accepts these imports and fails only when the code runs.
NATIVE_ONLY = re.compile(r"^import 'dart:(io|isolate)'", re.M)


def snippets(doc):
    text = (REPO / doc).read_text()
    for match in BLOCK.finditer(text):
        code = match.group(1)
        if re.search(r'^import ', code, re.M):
            yield text.count('\n', 0, match.start()) + 2, code


def broken_links(doc):
    """Relative links to missing files, links to missing files on this
    repository's main branch, and relative links that leave a package: a
    package's README is also its pub.dev and API docs page, where those break.
    """
    text = (REPO / doc).read_text()
    package = re.match(r'packages/[^/]+/', doc)
    for target in LINK.findall(text):
        repository = REPOSITORY.match(target)
        if repository:
            if not (REPO / repository.group(1).split('#', 1)[0]).exists():
                yield target
            continue
        if re.match(r'[a-z]+:', target) or target.startswith('#'):
            continue
        path = ((REPO / doc).parent / target.split('#', 1)[0]).resolve()
        if not path.exists():
            yield target
        elif package and not path.is_relative_to(REPO / package.group(0)):
            yield f'{target} (outside the package: link to GitHub instead)'


@functools.cache
def model_names(family):
    """The keys of the family's `XModels.byName`."""
    text = (PACKAGES / task_families()[family] / 'lib/models.dart').read_text()
    block = text[text.index('static const byName'):]
    return set(re.findall(r"'(\w+)':", block[:block.index('};')]))


def unknown_models(doc):
    """Names a `hooks.user_defines.<family>.models` sample lists that the
    family's `byName` lacks."""
    for family, listed in MODELS.findall((REPO / doc).read_text()):
        for name in re.findall(r'\w+', listed):
            if name not in model_names(family):
                yield f'mediapipe_{family} has no model named {name}'


def web_failures(app, origins):
    """Builds the snippets app for the web with every sample imported and
    returns what the build reports against them."""
    imports = ''.join(f"import '{name}' as s{index};\n"
                      for index, name in enumerate(origins))
    # The imports are what is checked: every sample must compile for the web.
    (app / 'lib/main.dart').write_text(f'{imports}\nvoid main() {{}}\n')
    result = subprocess.run(['flutter', 'build', 'web', '--no-pub'], cwd=app,
                            capture_output=True, text=True)
    if result.returncode == 0:
        return []
    output = result.stdout + result.stderr
    failures = []
    lines = output.splitlines() + ['']
    for line, message in zip(lines, lines[1:]):
        # dart2js prints the position, then the error on the next line.
        found = re.search(r'lib/(snippet_\d+\.dart):(\d+)', line)
        if found:
            failures.append(f'{origins[found.group(1)]} (+{found.group(2)}): '
                            f'web build: {message.strip()}')
    return failures or [f'web build failed:\n{output[-3000:]}']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('docs', nargs='*', default=DOCS)
    parser.add_argument('--skip-web', action='store_true',
                        help='analyze only, without the web build')
    args = parser.parse_args()
    failures = []
    for doc in args.docs:
        for target in broken_links(doc):
            failures.append(f'{doc}: broken link {target}')
        for problem in unknown_models(doc):
            failures.append(f'{doc}: {problem}')
    with tempfile.TemporaryDirectory(prefix='mediapipe-doc-') as tmp:
        app = Path(tmp) / 'doc_snippets'
        app.mkdir()
        # A web app scaffold, so the same app can also build for the web.
        subprocess.run(['flutter', 'create', '--platforms=web', '--no-pub',
                        '--project-name=doc_snippets', '.'], cwd=app,
                       check=True, capture_output=True)
        shutil.rmtree(app / 'test')
        (app / 'lib/main.dart').unlink()
        dependencies = ''.join(
            f'  {package_name(folder)}:\n    path: {PACKAGES / folder}\n'
            for folder in package_folders())
        # The families depend on mediapipe_core from pub.dev; the snippets
        # compile against this checkout's copy.
        overrides = (f'dependency_overrides:\n  mediapipe_core:\n'
                     f'    path: {PACKAGES / "mediapipe-core"}\n')
        (app / 'pubspec.yaml').write_text(f"""name: doc_snippets
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
{dependencies}{overrides}""")
        (app / 'analysis_options.yaml').write_text(
            'analyzer:\n  errors:\n    avoid_print: ignore\n')
        origins = {}
        for doc in args.docs:
            for line, code in snippets(doc):
                name = f'snippet_{len(origins)}.dart'
                (app / 'lib' / name).write_text(code)
                origins[name] = f'{doc}:{line}'
                for library in NATIVE_ONLY.findall(code):
                    failures.append(f'{doc}:{line}: imports dart:{library}, '
                                    'which browsers lack')
        subprocess.run(['flutter', 'pub', 'get'], cwd=app, check=True,
                       capture_output=True)
        result = subprocess.run(['flutter', 'analyze', '--no-fatal-infos'],
                                cwd=app, capture_output=True, text=True)
        for line in (result.stdout + result.stderr).splitlines():
            found = re.search(r'lib/(snippet_\d+\.dart):(\d+)', line)
            if found and ('error' in line or 'warning' in line):
                failures.append(f'{origins[found.group(1)]} (+{found.group(2)}): '
                                f'{line.strip()}')
        if not args.skip_web:
            failures += web_failures(app, origins)
        print(f'{len(origins)} Dart samples compiled from {len(args.docs)} docs')
    for failure in failures:
        print(failure)
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()

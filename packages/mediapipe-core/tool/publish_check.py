"""Runs `flutter pub publish --dry-run` for each package, as pub.dev would see it.

Each package is copied outside the repository, as git tracks it (pub applies
the enclosing repository's .gitignore and the package's .pubignore). The
family packages depend on `mediapipe_core` by version, and their checked-in
`pubspec_overrides.yaml` resolves it against the sibling copy, as a checkout
does; pub leaves that file out of the archive. Nothing is published: this
tool never runs `pub publish` without `--dry-run`.

Exit status is non-zero unless every package validates with zero warnings.
`archive_files` reads the files the dry run lists, which
tool/check_archives.py stages and builds an app against.
"""
import argparse
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile

CORE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(CORE / 'tool'))
from families import PACKAGES, package_folders  # noqa: E402

FAMILY = package_folders()


def copy(package, target):
    """Copies the files git would keep (tracked or new, not ignored)."""
    listed = subprocess.run(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
        cwd=PACKAGES / package, check=True, capture_output=True).stdout.decode()
    for relative in filter(None, listed.split('\0')):
        source = PACKAGES / package / relative
        if source.is_file() and not source.is_symlink():
            destination = target / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)


def prepare(package, root):
    target = root / package
    copy(package, target)
    return target


def flutter_dry_run():
    """The dry-run command. On Windows, flutter is a batch entry point that
    a bare name does not find (as tool_helpers.run resolves it)."""
    executable = 'flutter.bat' if platform.system() == 'Windows' else 'flutter'
    return [shutil.which(executable) or executable,
            'pub', 'publish', '--dry-run']


# One entry of the tree the dry run prints: the branch prefix, the name and,
# for a file, its size. Directories have no size. Pub draws the tree with
# Unicode box characters, or with `|-- `, `'-- ` and `|   ` on Windows.
TREE_ENTRY = re.compile(
    r"^((?:[│| ]   )*)(?:[├└]── |[|']-- )(.+?)"
    r"(?: \(((?:<1|\d+) [KMGT]?B)\))?$")


def archive_files(output):
    """The files `flutter pub publish --dry-run` lists in `output`, relative
    to the package: exactly what the archive would hold."""
    lines = output.splitlines()
    start = next((index for index, line in enumerate(lines)
                  if line.startswith('Publishing ')), None)
    if start is None:
        raise ValueError(f'The dry run listed no package:\n{output}')
    files, folders = [], []
    for line in lines[start + 1:]:
        entry = TREE_ENTRY.match(line)
        if not entry:
            break
        depth = len(entry.group(1)) // 4
        del folders[depth:]
        if entry.group(3) is None:
            folders.append(entry.group(2))
        else:
            files.append('/'.join([*folders, entry.group(2)]))
    if 'pubspec.yaml' not in files:
        raise ValueError(f'The dry run listed no pubspec.yaml:\n{output}')
    return files


def dry_run(package_dir):
    """Runs the dry run in `package_dir`, a copy from `prepare`, and returns
    its output; fails unless pub accepted the package. Pub writes UTF-8 on
    every host (the tree's box characters), whatever the console's code
    page says, so the output is decoded as such."""
    result = subprocess.run(flutter_dry_run(), cwd=package_dir,
                            capture_output=True, encoding='utf-8',
                            errors='replace')
    output = result.stdout + result.stderr
    if result.returncode != 0:
        raise RuntimeError(f'{package_dir.name}: the dry run failed:\n{output}')
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packages', nargs='*', default=FAMILY,
                        help='Package directories under packages/')
    args = parser.parse_args()
    failed = []
    with tempfile.TemporaryDirectory(prefix='mediapipe-publish-') as tmp:
        root = Path(tmp)
        for package in FAMILY:
            prepare(package, root)
        for package in args.packages:
            result = subprocess.run(flutter_dry_run(), cwd=root / package,
                                    capture_output=True, encoding='utf-8',
                                    errors='replace')
            output = result.stdout + result.stderr
            size = re.search(r'Total compressed archive size: (.+)\.', output)
            # The only expected hint: a family's mediapipe_core resolves
            # through its pubspec_overrides.yaml, as in a checkout.
            clean = re.search(r'Package has 0 warnings(\.| and)', output) is not None
            print(f'{package}: {"ok" if clean else "FAILED"}, '
                  f'archive {size.group(1) if size else "unknown"}', flush=True)
            if not clean:
                failed.append(package)
                report = output[output.find('Validating package'):]
                print(report or output, flush=True)
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()

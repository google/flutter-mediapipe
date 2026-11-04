"""What the maintainer tools share: a file's digest, a logged command, and
the layout of the generated JSON and Dart."""
import hashlib
import json
import platform
import shutil
import subprocess


def digest(path):
    """The SHA-256 of the file at `path`, in hex."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, cwd, log, env=None, timeout=3600, expect=0, tail=25):
    """Runs `command` in `cwd` with its output in `log`, prints the log's last
    `tail` lines and returns its text; fails unless the exit code is `expect`.

    On Windows, Dart and Flutter are batch entry points: a PATHEXT lookup can
    spell dart.EXE in upper case, after which Dart 3.12's hook runner appends
    another .exe, so both resolve to the .bat files Flutter's wrapper uses.
    """
    executable = str(command[0])
    if platform.system() == 'Windows' and executable in ('dart', 'flutter'):
        executable += '.bat'
    command = [shutil.which(executable) or executable, *map(str, command[1:])]
    print(' '.join(command), flush=True)
    with log.open('w', encoding='utf-8') as output:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=timeout)
    text = log.read_text(encoding='utf-8', errors='replace')
    print('\n'.join(text.splitlines()[-tail:]), flush=True)
    if result.returncode != expect:
        raise RuntimeError(f'Exit code {result.returncode}, expected {expect}: {log}')
    return text


def compact_json(value, indent=1, level=0):
    """`json.dumps(value, indent=indent)`, but with a list of numbers on one
    line, so a fixture of embeddings stays readable and short."""
    pad, inner = ' ' * indent * level, ' ' * indent * (level + 1)
    if isinstance(value, dict) and value:
        items = (f'{inner}{json.dumps(key)}: {compact_json(item, indent, level + 1)}'
                 for key, item in value.items())
        return '{\n' + ',\n'.join(items) + '\n' + pad + '}'
    if isinstance(value, list) and value:
        if all(isinstance(item, (int, float)) and not isinstance(item, bool)
               for item in value):
            return '[' + ', '.join(json.dumps(item) for item in value) + ']'
        items = (f'{inner}{compact_json(item, indent, level + 1)}' for item in value)
        return '[\n' + ',\n'.join(items) + '\n' + pad + ']'
    return json.dumps(value)


def reference_json(value, depth=3, level=0, **options):
    """`json.dumps(value, **options)` with only the first `depth` levels on
    lines of their own, so a reference fixture keeps one case's result per
    line instead of one number per line."""
    compact = json.dumps(value, separators=(', ', ': '), **options)
    items = value.values() if isinstance(value, dict) else value
    if (not isinstance(value, (dict, list)) or not value or level >= depth
            or not any(isinstance(item, (dict, list)) for item in items)):
        return compact
    pad, inner = '  ' * level, '  ' * (level + 1)
    if isinstance(value, dict):
        lines = (f'{inner}{json.dumps(key, **options)}: '
                 f'{reference_json(item, depth, level + 1, **options)}'
                 for key, item in value.items())
        return '{\n' + ',\n'.join(lines) + '\n' + pad + '}'
    lines = (inner + reference_json(item, depth, level + 1, **options) for item in value)
    return '[\n' + ',\n'.join(lines) + '\n' + pad + ']'


def dart_rows(items, indent, width=80):
    """The Dart elements `items`, each followed by a comma, packed into lines
    of at most `width` columns at `indent`, for a `// dart format off` list."""
    lines, line = [], ''
    for item in items:
        item = f'{item},'
        if line and len(line) + 1 + len(item) > width:
            lines.append(line)
            line = ''
        line = f'{line} {item}' if line else ' ' * indent + item
    return lines + [line] if line else lines

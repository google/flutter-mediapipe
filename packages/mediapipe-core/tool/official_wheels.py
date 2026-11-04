"""Google's official wheel pinned for this host, for the reference generators.

The pins are core's `referenceWheels`
(lib/src/native_assets/reference_wheels.dart), which the Dart tests check
every receipt against: Google's wheel of the MediaPipe release the family
libraries were built from. Every digest is checked again where it is used.
"""
import platform
import re
from pathlib import Path
import subprocess
import sys

CORE = Path(__file__).resolve().parents[1]
REFERENCE_WHEELS = CORE / 'lib/src/native_assets/reference_wheels.dart'


def _strings(source):
    return ''.join(re.findall(r"'([^']*)'", source))


def reference_wheel(target):
    """Core's `referenceWheels` row for `macos/arm64`, `linux/x64` or
    `windows/x64`."""
    source = REFERENCE_WHEELS.read_text(encoding='utf-8')
    row = re.search(r"'" + re.escape(target) + r"': \((.*?)\n  \),", source, re.S).group(1)
    return {
        'version': re.search(r"version: '([^']+)'", row).group(1),
        'library': re.search(r"libraryName: '([^']+)'", row).group(1),
        'library_sha256': _strings(re.search(r'librarySha256:(.*?),', row, re.S).group(1)),
        'wheel_url': _strings(re.search(r'url:(.*?),', row, re.S).group(1)),
        'wheel_sha256': _strings(re.search(r'wheelSha256:(.*?),', row, re.S).group(1)),
    }


MACOS = reference_wheel('macos/arm64')

def host_runtime():
    """The pinned official runtime for this host, or SystemExit where none is."""
    host = (platform.system(), platform.machine())
    target = {('Darwin', 'arm64'): 'macos/arm64', ('Linux', 'x86_64'): 'linux/x64',
              ('Windows', 'AMD64'): 'windows/x64'}.get(host)
    if target is None:
        raise SystemExit(f'No official wheel is pinned for {host[0]} {host[1]}.')
    return reference_wheel(target)


def venv_python(environment):
    """The interpreter inside a virtual environment created on this host."""
    return environment / ('Scripts/python.exe' if platform.system() == 'Windows' else 'bin/python')


def pinned_venv(environment, runtime, log=None):
    """The interpreter of the virtual environment at `environment` holding
    Google's wheel `runtime` (a `reference_wheel` row), both made when missing;
    pip's output goes to `log` when one is given."""
    python = venv_python(environment)
    if not python.exists():
        subprocess.run([sys.executable, '-m', 'venv', str(environment)], check=True)
    install = [str(python), '-m', 'pip', 'install', '--disable-pip-version-check',
               runtime['wheel_url'] + '#sha256=' + runtime['wheel_sha256']]
    if log is None:
        subprocess.run(install, check=True)
    else:
        with log.open('w', encoding='utf-8') as handle:
            subprocess.run(install, check=True, stdout=handle, stderr=subprocess.STDOUT)
    return python.absolute()

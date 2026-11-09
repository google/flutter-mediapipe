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
import time

CORE = Path(__file__).resolve().parents[1]
REFERENCE_WHEELS = CORE / 'lib/src/native_assets/reference_wheels.dart'

# Waits between pip's attempts; pip has spent its own retries when it exits, and
# it has none for a download that stalls.
PIP_WAITS = (15, 30)
PIP_LOG_TAIL = 40
_PIP_PERMANENT = re.compile(
    r'DO NOT MATCH THE HASHES|is not a supported wheel|HTTP error (?!408|429|5\d\d)\d{3}')
_PIP_NETWORK = re.compile(
    r'Read timed out|Max retries exceeded|Connection (?:reset|aborted)|IncompleteRead'
    r'|ProtocolError|HTTP error (?:408|429|5\d\d)|Retrying \(Retry\(total=0')
# A retry pip still had others after says nothing about why it finally failed.
_PIP_RECOVERED = re.compile(r'^.*Retrying \(Retry\(total=[1-9].*$', re.M)


def _strings(source):
    return ''.join(re.findall(r"'([^']*)'", source))


def reference_wheel(target, table='referenceWheels'):
    """Core's `referenceWheels` row, or the `table` named, for `macos/arm64`,
    `linux/x64` or `windows/x64`."""
    source = REFERENCE_WHEELS.read_text(encoding='utf-8')
    source = source[source.index(f'const {table} ='):]
    row = re.search(r"'" + re.escape(target) + r"': \((.*?)\n  \),", source, re.S).group(1)
    return {
        'version': re.search(r"version: '([^']+)'", row).group(1),
        'library': re.search(r"libraryName: '([^']+)'", row).group(1),
        'library_sha256': _strings(re.search(r'librarySha256:(.*?),', row, re.S).group(1)),
        'wheel_url': _strings(re.search(r'url:(.*?),', row, re.S).group(1)),
        'wheel_sha256': _strings(re.search(r'wheelSha256:(.*?),', row, re.S).group(1)),
    }


MACOS = reference_wheel('macos/arm64')

def host_runtime(table='referenceWheels'):
    """The pinned official runtime for this host in core's `table`, or
    SystemExit where none is."""
    host = (platform.system(), platform.machine())
    target = {('Darwin', 'arm64'): 'macos/arm64', ('Linux', 'x86_64'): 'linux/x64',
              ('Windows', 'AMD64'): 'windows/x64'}.get(host)
    if target is None:
        raise SystemExit(f'No official wheel is pinned for {host[0]} {host[1]}.')
    return reference_wheel(target, table)


def venv_python(environment):
    """The interpreter inside a virtual environment created on this host."""
    return environment / ('Scripts/python.exe' if platform.system() == 'Windows' else 'bin/python')


def network_failure(output):
    """Whether pip's `output` from a failed install blames the network, so the
    same install may work. Anything else, such as a hash mismatch or a version
    that does not exist, would fail the same way again."""
    if _PIP_PERMANENT.search(output):
        return False
    return _PIP_NETWORK.search(_PIP_RECOVERED.sub('', output)) is not None


def _show(text):
    # A Windows runner's console encoding cannot print everything pip can say.
    print(text.encode('ascii', 'replace').decode('ascii'), flush=True)


def pinned_venv(environment, runtime, log=None):
    """The interpreter of the virtual environment at `environment` holding
    Google's wheel `runtime` (a `reference_wheel` row), both made when missing;
    pip's output goes to `log` when one is given, and its end is printed if pip
    fails. Three attempts when the network is what failed."""
    python = venv_python(environment)
    if not python.exists():
        subprocess.run([sys.executable, '-m', 'venv', str(environment)], check=True)
    install = [str(python), '-m', 'pip', 'install', '--disable-pip-version-check',
               runtime['wheel_url'] + '#sha256=' + runtime['wheel_sha256']]
    logged = ''
    for wait in (*PIP_WAITS, None):
        result = subprocess.run(install, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                encoding='utf-8', errors='replace')
        if log is None:
            _show(result.stdout)
        else:
            logged += result.stdout
            log.write_text(logged, encoding='utf-8')
        if result.returncode == 0:
            return python.absolute()
        if wait is None or not network_failure(result.stdout):
            if log is not None:
                _show(f'The end of {log}:')
                _show('\n'.join(result.stdout.splitlines()[-PIP_LOG_TAIL:]))
            raise subprocess.CalledProcessError(result.returncode, install)
        _show(f'::warning::pip install of {runtime["wheel_url"]} failed on the network; '
              f'retrying in {wait} s')
        time.sleep(wait)

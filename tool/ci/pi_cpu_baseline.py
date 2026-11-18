"""Checks Google's Linux arm64 libraries against the Raspberry Pi CPUs, under qemu.

Google's aarch64 libraries are built for the LSE atomics and RCPC loads
(`ldaddal`, `ldapr`), and check for LSE when they load: on a CPU without it
they print "This binary was compiled with lse enabled, but this feature is
not available on this processor" and raise SIGILL. So they run on a
Raspberry Pi 5's Cortex-A76 and not on a Raspberry Pi 4's Cortex-A72, which
lacks both. doc/platform_setup.md says so; this keeps it true:

- qemu's emulated CPU is the one the library sees: AT_HWCAP has neither
  feature under cortex-a72 and both under cortex-a76.
- Every library core's `familyRuntimes` pins for linux/arm64 loads under
  cortex-a76 and stops with SIGILL under cortex-a72. A library that loads on
  cortex-a72 means Google's build changed, and the docs should say a Pi 4
  works.
- With --inference, the given package's tests pass under cortex-a76 and
  stop on that LSE check under cortex-a72, in a test VM qemu runs itself:
  `dart` starts that VM as a separate, unemulated process, so
  `qemu-aarch64 dart test` would test the host CPU.

Usage, on a Linux arm64 host with qemu-user installed:
  python3 -B tool/ci/pi_cpu_baseline.py [--inference packages/mediapipe-task-text test/language_detector_executor_test.dart]
"""
import argparse
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / 'packages' / 'mediapipe-core'
PI4 = 'cortex-a72'
PI5 = 'cortex-a76'
HWCAP_ATOMICS = 1 << 8
HWCAP_LRCPC = 1 << 15
HWCAP = ('import ctypes; '
         'print(ctypes.CDLL(None).getauxval(16))')
LOAD = 'import ctypes, sys; ctypes.CDLL(sys.argv[1])'
# What Google's libraries print before they raise SIGILL on a CPU without
# LSE. The test VM's crash handler then aborts, so its exit is SIGABRT.
FAIL_FAST = 'compiled with lse enabled, but this feature is not available'


def qemu(cpu, *command, **kwargs):
    return subprocess.run(['qemu-aarch64', '-cpu', cpu, *command], **kwargs)


def check_hwcap():
    for cpu, expected in ((PI4, False), (PI5, True)):
        output = qemu(cpu, sys.executable, '-I', '-c', HWCAP,
                      check=True, capture_output=True, text=True).stdout
        hwcap = int(output)
        atomics = bool(hwcap & HWCAP_ATOMICS)
        lrcpc = bool(hwcap & HWCAP_LRCPC)
        print(f'{cpu}: AT_HWCAP {hwcap:#x}, atomics {atomics}, lrcpc {lrcpc}')
        if atomics != expected or lrcpc != expected:
            sys.exit(f'qemu does not emulate {cpu}: atomics and lrcpc should be '
                     f'{expected}')


def linux_arm64_libraries(directory):
    inventory = subprocess.run(['dart', 'run', 'tool/runtime_inventory.dart'],
                               cwd=CORE, check=True, capture_output=True,
                               text=True).stdout
    entries = [dict(entry, release_asset=entry['file'])
               for entry in json.loads(inventory)
               if entry['target'] == 'linux/arm64']
    if not entries:
        sys.exit('familyRuntimes pins no linux/arm64 library')
    subprocess.run(['dart', 'run', 'tool/prefill_assets.dart', str(directory)],
                   cwd=CORE, check=True, input=json.dumps(entries), text=True)
    return [(entry['family'], directory / entry['sha256']) for entry in entries]


def check_libraries():
    problems = []
    with tempfile.TemporaryDirectory() as temporary:
        for family, library in linux_arm64_libraries(Path(temporary)):
            for cpu, loads in ((PI5, True), (PI4, False)):
                status = qemu(cpu, sys.executable, '-I', '-c', LOAD,
                              str(library)).returncode
                print(f'{family} on {cpu}: exit {status}')
                if loads and status != 0:
                    problems.append(f'{family} fails to load on {cpu} (exit {status})')
                elif not loads and status != -signal.SIGILL:
                    problems.append(
                        f'{family} on {cpu} exits {status}, not with SIGILL: if it '
                        'loads, Google\'s library now runs on a Raspberry Pi 4; '
                        'update doc/platform_setup.md and the changelogs')
    return problems


def test_vm_command(package, test, copies):
    """The `dartvm` command line `dart test` starts for `test`, captured live.

    That VM runs a kernel file from a temporary directory it deletes when it
    exits, and the kernel names the bundled libraries by their paths there.
    So the VM is paused while that directory is copied into `copies`, the
    copy goes back in its place once `dart test` is done, and the command
    returned keeps it. Returns the command and that directory.
    """
    process = subprocess.Popen(
        ['dart', 'test', '--reporter', 'expanded', test], cwd=package)
    command = temporary = None
    seen = set()
    while process.poll() is None and command is None:
        for pid in os.listdir('/proc'):
            if not pid.isdigit():
                continue
            try:
                arguments = Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
                cwd = os.readlink(f'/proc/{pid}/cwd')
            except OSError:
                continue
            arguments = tuple(argument.decode() for argument in arguments if argument)
            if not arguments or not arguments[0].endswith('/dartvm'):
                continue
            seen.add(arguments)
            if test in arguments and cwd == str(package):
                os.kill(int(pid), signal.SIGSTOP)
                try:
                    command, temporary = keep_temporary_files(list(arguments), copies)
                finally:
                    os.kill(int(pid), signal.SIGCONT)
                break
        time.sleep(0.02)
    if process.wait() != 0:
        sys.exit(f'{test} fails on this host, before any emulation')
    if command is None:
        for arguments in sorted(seen):
            print('dartvm:', ' '.join(arguments))
        sys.exit(f'Found no dartvm process for {test}')
    if temporary is not None:
        shutil.copytree(copies, temporary, dirs_exist_ok=True)
    return command, temporary


def keep_temporary_files(command, copies):
    flag = '--delete_temp_dir_on_shutdown='
    temporary = None
    for argument in command:
        if argument.startswith(flag):
            temporary = argument[len(flag):].rstrip('/')
            shutil.copytree(temporary, copies, dirs_exist_ok=True)
    return [argument for argument in command if not argument.startswith(flag)], temporary


def check_inference(package, test):
    package = (ROOT / package).resolve()
    problems = []
    with tempfile.TemporaryDirectory() as copies:
        command, temporary = test_vm_command(package, test, copies)
        print('Test VM:', ' '.join(command))
        try:
            for cpu, passes in ((PI5, True), (PI4, False)):
                start = time.monotonic()
                result = qemu(cpu, *command, cwd=package, capture_output=True,
                              text=True, errors='replace')
                status, output = result.returncode, result.stdout + result.stderr
                print(output)
                print(f'{test} on {cpu}: exit {status} after {time.monotonic() - start:.0f} s')
                if passes and status != 0:
                    problems.append(f'{test} fails on {cpu} (exit {status})')
                elif not passes and (status == 0 or FAIL_FAST not in output):
                    problems.append(f'{test} on {cpu} exits {status} without '
                                    f'"{FAIL_FAST}"')
        finally:
            if temporary is not None:
                shutil.rmtree(temporary, ignore_errors=True)
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--inference', nargs=2, metavar=('PACKAGE', 'TEST'),
                        help='a package directory and one of its test files')
    args = parser.parse_args()
    if platform.system() != 'Linux' or platform.machine() != 'aarch64':
        sys.exit('Run this on a Linux arm64 host')
    if not shutil.which('qemu-aarch64'):
        sys.exit('Install qemu-user: sudo apt-get install qemu-user')
    check_hwcap()
    problems = check_libraries()
    if args.inference:
        problems += check_inference(*args.inference)
    for problem in problems:
        print(f'::error::{problem}')
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()

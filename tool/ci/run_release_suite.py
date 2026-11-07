"""Runs one of the gallery's integration test suites in a release build.

`flutter test` and `flutter drive` build debug (or profile) apps only, and some
bugs show only in release builds: R8 on Android, AOT compilation, and Flutter
code that behaves differently under kReleaseMode, such as
RenderObject.debugSemantics, which release builds leave empty. So this builds
the suite as the release app itself, launches it, and reads flutter_test's own
report from the app's output (stdout on a desktop, logcat on Android) until its
last line: "All tests passed!" or "Some tests failed.". The app keeps running
after its tests, so it is stopped then.

Usage, from the repository root, after preparing the gallery:
  python3 -B tool/ci/run_release_suite.py --target macos \\
    --suite integration_test/gallery_journey_test.dart
  python3 -B tool/ci/run_release_suite.py --target android --device emulator-5554 \\
    --suite integration_test/sdk_all_test.dart --define SDK_GPU=skip
"""
import argparse
from pathlib import Path
import queue
import re
import subprocess
import sys
import threading
import time

GALLERY = Path(__file__).resolve().parents[2] / 'gallery'
NAME = 'mediapipe_gallery'
PACKAGE = 'com.example.mediapipe_gallery'
# flutter_test's last report line; a run that never prints one has stalled.
VERDICT = re.compile(r'(All tests passed!|Some tests failed\.)')
# How often a silent Android run is checked, in seconds, and how long it may
# stay silent. The longest silence in passing runs was 764 s, Decision Maker on
# the Android 9 emulator (November 6, 2026), where a stalled run went on to sit
# silent for its last 37 minutes (October 22).
POLL = 60
SILENCE = 1200
# What a failed build prints when the network failed it and a second build can
# pass: core's download of the native libraries (verified_download.dart: a
# host's passing error or a lost connection, not a SHA-256 mismatch or an HTTP
# 404), and Gradle's download of an Android SDK package.
NETWORK_ERROR = re.compile(
    r'Verified download failed: .*(?:HTTP (?:408|429|50[0234])\b|ClientException(?!: Redirect)'
    r'|SocketException|TimeoutException)'
    r'|An error occurred while preparing SDK package .*Error on ZipFile')
# Seconds before the one more build.
BUILD_RETRY_DELAY = 30
# gallery/lib/model_download_log.dart's lines. One counts as heard only if it
# reports more megabytes than the last for its file, which start again at each
# HTTP answer: a slow download finishes, while an answer with no bytes or a
# repeated line cannot hold off SILENCE. A line every 100 MB means a download
# slower than about 0.08 MB/s still ends at SILENCE, and a faster one that never
# finishes at the run's timeout.
PROGRESS = 'MODEL_DOWNLOAD '
DOWNLOAD = re.compile(r'^MODEL_DOWNLOAD (.+): (?:HTTP .*|(\d+)(?: of \d+)? MB in \d+ s(?:, ended)?)$')
EXECUTABLES = {
    'linux': f'build/linux/x64/release/bundle/{NAME}',
    'windows': f'build/windows/x64/runner/Release/{NAME}.exe',
    'macos': f'build/macos/Build/Products/Release/{NAME}.app/Contents/MacOS/{NAME}',
}


def run_build(command):
    """Runs the build, echoing its output; returns its exit status and whether
    the output names a network failure."""
    # Windows resolves flutter.bat only through the shell.
    process = subprocess.Popen(command, cwd=GALLERY, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, shell=sys.platform == 'win32')
    network = False
    for raw in process.stdout:
        line = raw.decode('utf-8', 'replace').rstrip()
        print(line, flush=True)
        network = network or NETWORK_ERROR.search(line) is not None
    return process.wait(), network


def build(args):
    defines = [f'--dart-define={define}' for define in args.define]
    if args.target == 'android':
        command = ['flutter', 'build', 'apk', '--release', '-t', args.suite,
                   '--target-platform', args.android_platform, *defines]
    else:
        command = ['flutter', 'build', args.target, '--release', '-t', args.suite, *defines]
    print('+ ' + ' '.join(command), flush=True)
    status, network = run_build(command)
    if status != 0 and network:
        print(f'::warning::The {args.target} release build failed on the network; '
              f'building once more in {BUILD_RETRY_DELAY} s.', flush=True)
        time.sleep(BUILD_RETRY_DELAY)
        status, _ = run_build(command)
    if status != 0:
        raise subprocess.CalledProcessError(status, command)


def death_check(adb):
    """A function that says whether the Android app has died, or its device has
    gone: no process twice running, once it has been seen. The -s flutter:I
    logcat shows neither, so the run would otherwise wait out its limit."""
    seen = False
    misses = 0

    def dead():
        nonlocal seen, misses
        try:
            pid = subprocess.run([*adb, 'shell', 'pidof', PACKAGE], capture_output=True,
                                 text=True, timeout=30).stdout.strip()
        except subprocess.TimeoutExpired:
            pid = ''
        seen = seen or bool(pid)
        misses = 0 if pid else misses + 1
        return seen and misses >= 2
    return dead


def launch(args):
    """Starts the release app; returns the process whose output carries its
    report, a function that stops the app, and on Android a death_check."""
    if args.target != 'android':
        app = subprocess.Popen([str(GALLERY / EXECUTABLES[args.target])], cwd=GALLERY,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return app, app.kill, None
    adb = ['adb', '-s', args.device]
    apk = GALLERY / 'build/app/outputs/flutter-apk/app-release.apk'
    # -g grants the manifest's runtime permissions, the camera among them, so
    # no live page waits behind a permission prompt.
    subprocess.run([*adb, 'install', '-r', '-g', str(apk)], check=True)
    subprocess.run([*adb, 'logcat', '-c'], check=True)
    log = subprocess.Popen([*adb, 'logcat', '-v', 'raw', '-s', 'flutter:I'],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    subprocess.run([*adb, 'shell', 'am', 'start', '-W', '-n', f'{PACKAGE}/.MainActivity'],
                   check=True)

    def stop():
        try:
            subprocess.run([*adb, 'shell', 'am', 'force-stop', PACKAGE], check=False, timeout=60)
        except subprocess.TimeoutExpired:
            print('The device did not answer force-stop.', flush=True)
        log.kill()
    return log, stop, death_check(adb)


def dump_log(device):
    """The device's whole recent log: the run's own logcat shows only Flutter's
    lines, which leave out a crash or a low-memory kill."""
    print("The emulator's log follows.", flush=True)
    try:
        subprocess.run(['adb', '-s', device, 'logcat', '-d', '-t', '300'], check=False, timeout=60)
    except subprocess.TimeoutExpired:
        print('The device did not answer logcat.', flush=True)


def heard_from(line, received):
    """Whether [line] shows the app moving: any line but a download's, or a
    download's with more megabytes than [received], the counts so far by file."""
    if not line.startswith(PROGRESS):
        return True
    match = DOWNLOAD.match(line)
    if not match:
        return False
    name, megabytes = match.groups()
    if megabytes is None:
        received[name] = 0
        return False
    if int(megabytes) <= received.get(name, 0):
        return False
    received[name] = int(megabytes)
    return True


def verdict(process, timeout, dead=None):
    """flutter_test's last report line, echoing the app's output, or None if
    none arrives within [timeout] seconds or, given a death_check, if the app
    dies or stays silent for SILENCE seconds."""
    lines = queue.Queue()

    def read():
        for raw in process.stdout:
            lines.put(raw.decode('utf-8', 'replace').rstrip())
        lines.put(None)
    threading.Thread(target=read, daemon=True).start()
    deadline = time.monotonic() + timeout
    heard = time.monotonic()
    progress = None
    received = {}
    while (left := deadline - time.monotonic()) > 0:
        try:
            line = lines.get(timeout=min(left, POLL))
        except queue.Empty:
            if dead and dead():
                print('The app or its device has gone.', flush=True)
                return None
        else:
            if line is None:
                return None
            print(line, flush=True)
            if match := VERDICT.search(line):
                return match.group(1)
            if line.startswith(PROGRESS):
                progress = line
            if heard_from(line, received):
                heard = time.monotonic()
        if dead and time.monotonic() - heard > SILENCE:
            print(f'The app has been silent for over {SILENCE} s.', flush=True)
            break
    if progress:
        print(f'Its last download line: {progress}', flush=True)
    return None


def main():
    # Flutter and the suites print Unicode; Windows CI defaults to cp1252.
    sys.stdout.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--target', required=True, choices=['linux', 'windows', 'macos', 'android'])
    parser.add_argument('--suite', required=True, help='Path under gallery/')
    parser.add_argument('--define', action='append', default=[], help='KEY=VALUE, repeatable')
    parser.add_argument('--device', help='The adb serial, for android')
    parser.add_argument('--android-platform', default='android-x64')
    parser.add_argument('--timeout', type=int, default=2400, help='Seconds for the tests')
    args = parser.parse_args()
    if args.target == 'android' and not args.device:
        parser.error('--device is required for android')
    build(args)
    process, stop, dead = launch(args)
    try:
        result = verdict(process, args.timeout, dead)
        if result is None and args.target == 'android':
            dump_log(args.device)
    finally:
        stop()
    if result is None:
        print(f'{args.suite} reported no verdict in release within {args.timeout} s.', flush=True)
        sys.exit(1)
    print(f'{args.suite} in release on {args.target}: {result}', flush=True)
    sys.exit(0 if result == 'All tests passed!' else 1)


if __name__ == '__main__':
    main()

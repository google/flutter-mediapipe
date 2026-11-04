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
EXECUTABLES = {
    'linux': f'build/linux/x64/release/bundle/{NAME}',
    'windows': f'build/windows/x64/runner/Release/{NAME}.exe',
    'macos': f'build/macos/Build/Products/Release/{NAME}.app/Contents/MacOS/{NAME}',
}


def build(args):
    defines = [f'--dart-define={define}' for define in args.define]
    if args.target == 'android':
        command = ['flutter', 'build', 'apk', '--release', '-t', args.suite,
                   '--target-platform', args.android_platform, *defines]
    else:
        command = ['flutter', 'build', args.target, '--release', '-t', args.suite, *defines]
    print('+ ' + ' '.join(command), flush=True)
    # Windows resolves flutter.bat only through the shell.
    subprocess.run(command, cwd=GALLERY, check=True, shell=sys.platform == 'win32')


def launch(args):
    """Starts the release app; returns the process whose output carries its
    report, and a function that stops the app."""
    if args.target != 'android':
        app = subprocess.Popen([str(GALLERY / EXECUTABLES[args.target])], cwd=GALLERY,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return app, app.kill
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
        subprocess.run([*adb, 'shell', 'am', 'force-stop', PACKAGE], check=False)
        log.kill()
    return log, stop


def verdict(process, timeout):
    """flutter_test's last report line, echoing the app's output, or None if
    none arrives within [timeout] seconds."""
    lines = queue.Queue()

    def read():
        for raw in process.stdout:
            lines.put(raw.decode('utf-8', 'replace').rstrip())
        lines.put(None)
    threading.Thread(target=read, daemon=True).start()
    deadline = time.monotonic() + timeout
    while (left := deadline - time.monotonic()) > 0:
        try:
            line = lines.get(timeout=left)
        except queue.Empty:
            break
        if line is None:
            return None
        print(line, flush=True)
        if match := VERDICT.search(line):
            return match.group(1)
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
    process, stop = launch(args)
    try:
        result = verdict(process, args.timeout)
    finally:
        stop()
    if result is None:
        print(f'{args.suite} reported no verdict in release within {args.timeout} s.', flush=True)
        sys.exit(1)
    print(f'{args.suite} in release on {args.target}: {result}', flush=True)
    sys.exit(0 if result == 'All tests passed!' else 1)


if __name__ == '__main__':
    main()

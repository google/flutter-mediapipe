"""Makes `flutter test` on an iOS simulator wait for its log reader.

The Flutter tool finds a simulator app's Dart VM service by reading the line
"The Dart VM service is listening on ..." from `simctl spawn log stream`. It
starts that reader and launches the app without waiting for the reader to
attach, and the app prints the line once, about a second after launch. On a
busy hosted runner the reader can attach later than that; the line is lost and
`flutter test` waits for it forever. The app itself launched and is listening.

This inserts a short wait between starting the reader and launching the app in
the runner's Flutter SDK, then drops the tool's stamp so the next `flutter`
command rebuilds the tool. Hosted runners only: it edits the installed SDK.
"""
import pathlib
import shutil
import subprocess
import sys

ANCHOR = '      await _simControl.launch(id, bundleIdentifier, launchArguments);\n'
WAIT = ('      // Patched in CI: let the log reader attach before the app prints its\n'
        '      // VM service line (tool/ci/patch_flutter_simulator_launch.py).\n'
        '      await Future<void>.delayed(const Duration(seconds: 5));\n')


def main():
    flutter = shutil.which('flutter')
    if flutter is None:
        sys.exit('flutter is not on PATH')
    root = pathlib.Path(flutter).resolve().parent.parent
    source = root / 'packages/flutter_tools/lib/src/ios/simulators.dart'
    text = source.read_text(encoding='utf-8')
    if WAIT in text:
        print(f'{source}: already patched', flush=True)
        return
    if text.count(ANCHOR) != 1:
        sys.exit(f'{source}: the simulator launch call changed; update this patch')
    source.write_text(text.replace(ANCHOR, WAIT + ANCHOR), encoding='utf-8')
    print(f'{source}: waits 5 s for the log reader before launching', flush=True)
    (root / 'bin/cache/flutter_tools.stamp').unlink(missing_ok=True)
    subprocess.run([flutter, '--version'], check=True)


if __name__ == '__main__':
    main()

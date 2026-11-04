import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';
import 'package:test/test.dart';

TaskCapabilities _support(TaskPlatform platform) =>
    TaskCapabilities.cpuOnTargets(
      platform: platform,
      gpuUnavailableReason: 'Upstream GPU failure.',
      runtimeVersion: '1.1.0',
      targets: const {'macos/arm64': '14.0'},
    );

void main() {
  test(
    'delegate-specific target and minimum versions are checked independently',
    () {
      TaskCapabilities check(String os, String? version) =>
          TaskCapabilities.onTargets(
            platform: TaskPlatform(
              operatingSystem: os,
              architecture: 'x64',
              version: version,
            ),
            delegates: const {
              Delegate.cpu: {'windows/x64': '10.0', 'linux/x64': null},
              Delegate.gpu: {'windows/x64': '11.0'},
            },
            unavailableReasons: const {Delegate.gpu: 'GPU requires Windows.'},
            runtimeVersion: '1.0.0',
          );
      expect(check('windows', '10.0').supportedDelegates, {Delegate.cpu});
      expect(
        check('windows', '10.0').unavailableReasons[Delegate.gpu],
        contains('11.0'),
      );
      expect(
        check('windows', '11.0').supportedDelegates,
        Delegate.values.toSet(),
      );
      expect(check('windows', null).supportedDelegates, isEmpty);
      expect(check('linux', null).supportedDelegates, {Delegate.cpu});
      expect(
        check('linux', null).unavailableReasons[Delegate.gpu],
        'GPU requires Windows.',
      );
      expect(check('windows', '11.0').minimumOperatingSystemVersion, '10.0');
      expect(
        () => check('linux', null).supportedTargets.clear(),
        throwsUnsupportedError,
      );
    },
  );
  // Google builds every family for 32-bit Android too; the tasks whose
  // models it cannot hold stay on 64-bit processes, and say why.
  test('32-bit Android runs the shared targets but not the large models', () {
    const arm32 = TaskPlatform(operatingSystem: 'android', architecture: 'arm');
    TaskCapabilities on(RuntimeTargets targets) =>
        TaskCapabilities.cpuOnTargets(
          platform: arm32,
          gpuUnavailableReason: 'CPU only.',
          runtimeVersion: '1.2.0',
          targets: targets,
        );
    expect(tasksRuntimeTargets.keys, contains('android/arm'));
    expect(largeModelRuntimeTargets.keys, isNot(contains('android/arm')));
    expect(
      tasksRuntimeTargets.keys.toSet().difference(
        largeModelRuntimeTargets.keys.toSet(),
      ),
      {'android/arm'},
    );
    expect(on(tasksRuntimeTargets).supportedDelegates, {Delegate.cpu});
    final large = on(largeModelRuntimeTargets);
    expect(large.supportedDelegates, isEmpty);
    expect(large.unavailableReasons[Delegate.cpu], largeModelNeeds64Bit);
  });

  test('minimum OS accepts CPU and preserves the upstream GPU explanation', () {
    final result = _support(
      const TaskPlatform(
        operatingSystem: 'macos',
        architecture: 'arm64',
        version: '14.0',
      ),
    );
    expect(result.supportedDelegates, {Delegate.cpu});
    expect(result.unavailableReasons[Delegate.gpu], 'Upstream GPU failure.');
    expect(result.unavailableReasons.containsKey(Delegate.cpu), isFalse);
    expect(
      () => result.supportedDelegates.add(Delegate.gpu),
      throwsUnsupportedError,
    );
    expect(() => result.unavailableReasons.clear(), throwsUnsupportedError);
  });

  test('old, unknown, Intel/Rosetta, mobile and web platforms fail closed', () {
    for (final platform in [
      const TaskPlatform(
        operatingSystem: 'macos',
        architecture: 'arm64',
        version: '13.6',
      ),
      const TaskPlatform(operatingSystem: 'macos', architecture: 'arm64'),
      const TaskPlatform(
        operatingSystem: 'macos',
        architecture: 'x64',
        version: '26.4',
      ),
      const TaskPlatform(
        operatingSystem: 'ios',
        architecture: 'arm64',
        version: '26.4',
      ),
      const TaskPlatform(operatingSystem: 'linux', architecture: 'arm64'),
      const TaskPlatform(operatingSystem: 'web', architecture: 'unknown'),
    ]) {
      final result = _support(platform);
      expect(result.isSupported, isFalse);
      expect(result.unavailableReasons.keys, containsAll(Delegate.values));
    }
  });

  test(
    'current platform inspection succeeds without MediaPipe native assets',
    () async {
      final platform = await currentTaskPlatform();
      expect(platform.operatingSystem, isNotEmpty);
      // Both Darwin systems answer kern.osproductversion, and a capability
      // table that carries a minimum version needs it on either one.
      if (platform.operatingSystem == 'macos' ||
          platform.operatingSystem == 'ios') {
        expect(platform.version, matches(r'^\d+(\.\d+)*$'));
        expect(platform.architecture, anyOf('arm64', 'x64'));
      }
      expect(platform.browserEngine, isNull);
    },
  );

  test('a user agent names its browser engine, and every iOS browser is '
      'WebKit', () {
    const agents = {
      // Playwright's WebKit 26.6 and Chromium 153 on macOS.
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
              '(KHTML, like Gecko) Version/26.6 Safari/605.1.15':
          BrowserEngine.webkit,
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) HeadlessChrome/153.0.0.0 Safari/537.36':
          BrowserEngine.blink,
      'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 '
              'Mobile/15E148 Safari/604.1':
          BrowserEngine.webkit,
      'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/141.0.0.0 '
              'Mobile/15E148 Safari/604.1':
          BrowserEngine.webkit,
      'Mozilla/5.0 (iPad; CPU OS 26_0 like Mac OS X) AppleWebKit/605.1.15 '
              '(KHTML, like Gecko) FxiOS/143.0 Mobile/15E148 Safari/605.1.15':
          BrowserEngine.webkit,
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 '
              'Edg/141.0.0.0':
          BrowserEngine.blink,
      'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36':
          BrowserEngine.blink,
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) '
              'Gecko/20100101 Firefox/143.0':
          BrowserEngine.gecko,
      '': null,
    };
    for (final MapEntry(key: agent, value: engine) in agents.entries) {
      expect(BrowserEngine.fromUserAgent(agent), engine, reason: agent);
    }
    expect(
      const TaskPlatform(
        operatingSystem: 'web',
        architecture: 'unknown',
        browserEngine: BrowserEngine.webkit,
      ).toString(),
      'TaskPlatform(web/unknown, webkit)',
    );
  });
}

import '../delegate.dart';
import '../exceptions.dart';

/// A browser's engine, for a task whose browser runtime fails in one of them.
enum BrowserEngine {
  /// Safari, and every browser on iOS and iPadOS.
  webkit,

  /// Chrome, Edge, Opera and the other Chromium browsers.
  blink,

  /// Firefox outside iOS.
  gecko;

  /// The engine [userAgent] names; null when it names none of these. Every
  /// browser on iOS and iPadOS runs WebKit, whatever its own name.
  static BrowserEngine? fromUserAgent(String userAgent) {
    if (RegExp(r'\b(iPhone|iPad|iPod)\b').hasMatch(userAgent)) return webkit;
    final appleWebKit = userAgent.contains('AppleWebKit/');
    if (!appleWebKit && userAgent.contains('Firefox/')) return gecko;
    if (!appleWebKit) return null;
    return RegExp(r'\b(Chrome|Chromium|HeadlessChrome)/').hasMatch(userAgent)
        ? blink
        : webkit;
  }
}

/// The current process platform, including its ABI (not the host CPU's ABI).
final class TaskPlatform {
  /// Construct a platform snapshot. A null OS version means it is unknown.
  const TaskPlatform({
    required this.operatingSystem,
    required this.architecture,
    this.version,
    this.gpu,
    this.simulator = false,
    this.browserEngine,
  });

  /// Dart operating system name, or `web` outside native platforms.
  final String operatingSystem;

  /// Process architecture, e.g. `arm64` or `x64`.
  final String architecture;

  /// Product version such as `14.0`, rather than the Darwin kernel version.
  final String? version;

  /// The GPU's OpenGL ES renderer and vendor where an adapter names them (the
  /// Android vision adapter does), e.g. `Mali-G715 (ARM)`; null when unknown.
  /// A task that fails on one GPU family can then declare it unsupported.
  final String? gpu;

  /// Whether this process runs in Apple's iOS Simulator rather than on a
  /// device. The target is still `ios/arm64`, but a GPU path can differ.
  final bool simulator;

  /// The browser's engine on the web, read from its user agent; null on
  /// native platforms and in a browser it does not recognize.
  final BrowserEngine? browserEngine;

  /// `operatingSystem/architecture`, the key used by runtime target tables.
  String get target => '$operatingSystem/$architecture';

  @override
  String toString() =>
      'TaskPlatform($target${version == null ? '' : ' $version'}'
      '${gpu == null ? '' : ', $gpu'}${simulator ? ', simulator' : ''}'
      '${browserEngine == null ? '' : ', ${browserEngine!.name}'})';
}

/// Names this device's GPU for [TaskPlatform.gpu]. An adapter package that can
/// read it sets this when it registers, before the platform is first read; it
/// is called once, with the rest of the platform.
Future<String?> Function()? taskPlatformGpuReader;

/// What [taskPlatformGpuReader] names, or null without one or when it fails:
/// an unnamed GPU leaves every capability table as declared.
Future<String?> readTaskPlatformGpu() async {
  try {
    return await taskPlatformGpuReader?.call();
  } on Object {
    return null;
  }
}

/// Minimum product version for one process target, e.g. `macos/arm64: 14.0`.
///
/// A null version means any version of that operating system is accepted.
typedef RuntimeTargets = Map<String, String?>;

/// Process targets where each task family bundles Google's MediaPipe library
/// for that family, which serves the Audio Classifier and every text task:
/// the classifier, embedder (EmbeddingGemma included), language detector,
/// Proofreader and Summarizer.
///
/// This mirrors core's build-time table of Google's libraries
/// (`familyRuntimes`); the two are kept in step so that a platform is never
/// reported supported without a library, or bundled without a validated
/// support claim. 32-bit Android (armeabi-v7a), whose libraries Google
/// builds for API 28 too, serves the tasks whose models it can hold; see
/// [largeModelRuntimeTargets].
const tasksRuntimeTargets = <String, String?>{
  ...largeModelRuntimeTargets,
  'android/arm': null,
};

/// [tasksRuntimeTargets] on 64-bit processes only, for the tasks whose
/// models need more memory than a 32-bit Android phone gives an app:
/// Decision Maker's, the retrieval tasks', EmbeddingGemma, and the
/// Proofreader's and Summarizer's.
const largeModelRuntimeTargets = <String, String?>{
  'macos/arm64': '14.0',
  'linux/x64': null,
  'windows/x64': null,
  'ios/arm64': '15.0',
  // Android 9 (API 28) and later; the hooks refuse a lower minSdk.
  'android/arm64': null,
  'android/x64': null,
};

/// Why a task on [largeModelRuntimeTargets] refuses 32-bit Android.
const largeModelNeeds64Bit =
    "This task's models need more memory than a 32-bit Android process "
    '(armeabi-v7a) holds, so it runs on 64-bit Android (arm64-v8a or '
    'x86_64). Vision, classic text and audio tasks run on 32-bit Android.';

/// Why [task] cannot run in this process on [operatingSystem]
/// ([TaskPlatform.operatingSystem]): the build bundled no MediaPipe library
/// for it, as happens when the app was built without its package's build
/// hook running.
String tasksRuntimeUnavailable(String task, String operatingSystem) =>
    "$task runs on Google's MediaPipe library, which its package's build "
    'hook bundles on $operatingSystem, but this build has none. Build the '
    'app with flutter run or flutter build (or dart run and dart test for a '
    'Dart program), which run the hook.';

/// What a family reports in a browser where [package]'s plugin never
/// registered: its native stubs throw it, and its capability queries give
/// its message and fix as their reason.
RuntimeUnavailableException pluginNotRegistered(String package) =>
    RuntimeUnavailableException(
      'The $package browser plugin did not register.',
      fix:
          'Depend on $package as a Flutter plugin so its web registration '
          'runs before the first task is created.',
    );

/// The official MediaPipe release behind the tasks on [platform]: Google's
/// 1.2.0 per-family libraries (its nightly build of October 18, 2026) on
/// Android, iOS, macOS, Linux and Windows, and in browsers its runtime from
/// the same night's npm nightly.
String tasksRuntimeVersionOn(TaskPlatform platform) =>
    platform.operatingSystem == 'web' ? '1.2.0-rc.20261018' : '1.2.0';

/// Declared package support for one task on a platform: which [Delegate]s run
/// there and why the others do not. This is not an inference self-test.
///
/// Model validity, native-asset opt-in, and available memory are checked when
/// creating a task. Querying support does not download assets or initialize
/// the GPU.
final class TaskCapabilities {
  /// Describe delegates whose validated target sets differ.
  ///
  /// Each delegate is checked against its own minimum OS version. Unsupported
  /// delegates use [unavailableReasons], or the target mismatch diagnostic.
  factory TaskCapabilities.onTargets({
    required TaskPlatform platform,
    required Map<Delegate, RuntimeTargets> delegates,
    required Map<Delegate, String> unavailableReasons,
    required String runtimeVersion,
  }) {
    final supported = <Delegate>{};
    final reasons = <Delegate, String>{};
    final targets = <String, String?>{};
    for (final entry in delegates.entries) {
      for (final target in entry.value.entries) {
        if (!targets.containsKey(target.key) ||
            target.value == null ||
            (targets[target.key] != null &&
                _compareVersions(target.value!, targets[target.key]!) < 0)) {
          targets[target.key] = target.value;
        }
      }
      final reason = _platformReason(platform, entry.value);
      if (reason == null) {
        supported.add(entry.key);
      } else {
        reasons[entry.key] = entry.value.containsKey(platform.target)
            ? reason
            : unavailableReasons[entry.key] ?? reason;
      }
    }
    return TaskCapabilities._(
      platform,
      Set.unmodifiable(supported),
      Map.unmodifiable(reasons),
      Map.unmodifiable(targets),
      runtimeVersion: runtimeVersion,
    );
  }

  /// Describe CPU support on every target in [targets], with the GPU explained
  /// as unavailable by [gpuUnavailableReason] on targets that are supported.
  ///
  /// Targets not in the table, unknown OS versions and versions older than the
  /// table's minimum fail closed for every delegate.
  factory TaskCapabilities.cpuOnTargets({
    required TaskPlatform platform,
    required String gpuUnavailableReason,
    required String runtimeVersion,
    RuntimeTargets targets = tasksRuntimeTargets,
  }) {
    final platformReason = _platformReason(platform, targets);
    return TaskCapabilities._(
      platform,
      Set.unmodifiable({if (platformReason == null) Delegate.cpu}),
      Map.unmodifiable({
        Delegate.cpu: ?platformReason,
        Delegate.gpu: platformReason ?? gpuUnavailableReason,
      }),
      targets,
      runtimeVersion: runtimeVersion,
    );
  }

  const TaskCapabilities._(
    this.platform,
    this.supportedDelegates,
    this.unavailableReasons,
    this._targets, {
    required this.runtimeVersion,
  });

  /// Current process platform used to evaluate support.
  final TaskPlatform platform;

  /// Delegates supported by this package on the current process platform.
  final Set<Delegate> supportedDelegates;

  /// A human-readable explanation for each unavailable delegate.
  final Map<Delegate, String> unavailableReasons;

  /// Pinned upstream runtime version behind these tasks.
  final String runtimeVersion;

  final RuntimeTargets _targets;

  /// Whether at least one delegate is supported on this platform.
  bool get isSupported => supportedDelegates.isNotEmpty;

  /// Process targets with a validated runtime, and their minimum OS versions.
  RuntimeTargets get supportedTargets => Map.unmodifiable(_targets);

  /// Minimum product version of the operating system the packaged native
  /// runtime requires, if any: the current platform's when it is supported,
  /// otherwise the first supported target's.
  String? get minimumOperatingSystemVersion => _targets[_reference];

  String get _reference => _targets.containsKey(platform.target)
      ? platform.target
      : _targets.keys.first;

  @override
  String toString() =>
      'TaskCapabilities($platform, supported: $supportedDelegates, '
      'runtime $runtimeVersion)';

  static String? _platformReason(
    TaskPlatform platform,
    RuntimeTargets targets,
  ) {
    if (!targets.containsKey(platform.target)) {
      if (platform.target == 'android/arm' &&
          targets.containsKey('android/arm64')) {
        return largeModelNeeds64Bit;
      }
      final supported = targets.entries
          .map((e) => e.value == null ? e.key : '${e.key} (${e.value}+)')
          .join(', ');
      return 'Requires one of $supported. This process is ${platform.target}.';
    }
    final minimum = targets[platform.target];
    if (minimum == null) return null;
    final name = _displayName(platform.operatingSystem);
    final major = int.tryParse(platform.version?.split('.').first ?? '');
    if (major == null) {
      return 'Could not verify the required $name version ($minimum or later).';
    }
    if (_compareVersions(platform.version!, minimum) < 0) {
      return 'Requires $name $minimum or later; found ${platform.version}.';
    }
    return null;
  }

  static String _displayName(String operatingSystem) =>
      switch (operatingSystem) {
        'macos' => 'macOS',
        'ios' => 'iOS',
        'android' => 'Android',
        'windows' => 'Windows',
        'linux' => 'Linux',
        _ => operatingSystem,
      };

  static int _compareVersions(String a, String b) {
    final left = a.split('.').map(int.tryParse).toList();
    final right = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < left.length || i < right.length; i++) {
      final l = i < left.length ? left[i] ?? 0 : 0;
      final r = i < right.length ? right[i] ?? 0 : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }
}

/// Fails with the capability query's reason when [delegate] is unavailable,
/// so every task's `create` refuses a delegate the same way on every
/// platform.
void requireDelegate(TaskCapabilities capabilities, Delegate delegate) {
  if (capabilities.supportedDelegates.contains(delegate)) return;
  throw RuntimeUnavailableException(
    'The ${delegate.name.toUpperCase()} delegate is unavailable here.',
    fix:
        capabilities.unavailableReasons[delegate] ??
        'Choose a delegate the capability query reports as supported.',
  );
}

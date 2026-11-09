/// Audio Classifier's delegate support, queried without loading a model.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import 'audio_task_backend.dart'
    show audioTaskBackendFactory, audioTranscriberOpener, browserOnMac;

/// Where Audio Classifier runs: CPU on Google's audio library on Android,
/// iOS 15+, macOS 14+ arm64, Linux x64 and Windows x64, and through Google's
/// browser runtime where the web plugin installs it.
Future<TaskCapabilities> queryAudioClassifierCapabilities() async =>
    audioClassifierCapabilitiesForPlatform(await currentTaskPlatform());

/// Audio Classifier support on [platform], without loading code.
TaskCapabilities audioClassifierCapabilitiesForPlatform(
  TaskPlatform platform,
) => TaskCapabilities.cpuOnTargets(
  platform: platform,
  gpuUnavailableReason: "Google's official audio task runs on CPU only.",
  runtimeVersion: tasksRuntimeVersionOn(platform),
  targets: {
    ...tasksRuntimeTargets,
    // A registered backend is Google's browser runtime.
    if (audioTaskBackendFactory != null) 'web/unknown': null,
  },
);

/// Where Google's speech tasks run: core's 64-bit targets, whose library
/// has Audio Transcriber and Text to Speech since 1.2.2.
const speechRuntimeTargets = largeModelRuntimeTargets;

const _speechNoLibrary =
    "Google's audio library has the speech tasks on Android arm64 and "
    'x86_64, iOS, macOS arm64, Linux x64 and Windows x64.';

const _speechNoBrowserPlugin =
    "The speech tasks' browser runtime needs this package's web plugin, which "
    'a Flutter web build registers.';

// Which models Text to Speech runs on the GPU, as Google's guide lists them.
const _textToSpeechGpuModels =
    "Google's Text to Speech uses the GPU delegate only for Kokoro "
    '(kokoro_int8_gpu_fp16.litertlm), whose vocoder runs there: Phonon and '
    'PocketTTS run on the CPU.';

const _textToSpeechGpuUnproved =
    "This package offers Text to Speech's GPU delegate only where a test "
    'proved the GPU does the work: Kokoro on macOS 15 or later on arm64. No '
    'such test has run on this platform yet. $_textToSpeechGpuModels';

const _textToSpeechWebGpuUnproved =
    "This package offers Text to Speech's GPU delegate only where a test "
    'proved the GPU does the work: Kokoro on macOS 15 or later on arm64. No '
    'such test has run in a browser yet. $_textToSpeechGpuModels';

const _transcriberGpuUnproved =
    "This package offers Audio Transcriber's GPU delegate only where a test "
    "proved the GPU does the work, as Google's library can accept the delegate "
    'and stay on the CPU. No such test has run on this platform yet.';

String _transcriberNoWebGpu(TaskPlatform platform) =>
    "Google's browser Audio Transcriber needs a hardware WebGPU adapter for "
    'the GPU delegate: without one Chromium silently stays on the CPU and '
    'Firefox fails to create the task. This browser has '
    '${platform.gpu ?? 'no WebGPU adapter'}.';

const _transcriberWebGpuUnproved =
    "This package offers Audio Transcriber's browser GPU delegate only where "
    "a test proved the GPU does the work: Chromium and WebKit on a Mac's Apple "
    'adapter.';

/// The adapter vendor [_webGpuProved] takes, as `readWebGpuAdapter` names it.
final _appleWebGpu = RegExp(r'^WebGPU apple\b');

/// Whether the browser suite saw the GPU do the transcriber's work in this
/// browser: Chromium on a Mac's Apple adapter, which CI's browser job checks
/// on macOS 15, and WebKit on that adapter, checked only on a developer's Mac.
/// Firefox has no adapter where it was tried, and no test has run on any
/// other adapter or on an iPhone or iPad.
bool _webGpuProved(TaskPlatform platform) =>
    browserOnMac &&
    hasHardwareWebGpu(platform) &&
    _appleWebGpu.hasMatch(platform.gpu!) &&
    switch (platform.browserEngine) {
      BrowserEngine.blink || BrowserEngine.webkit => true,
      _ => false,
    };

/// Where Audio Transcriber's native GPU delegate is offered: Metal on macOS
/// arm64, which the package's tests prove on macOS 15, the only version CI
/// runs (they passed once on macOS 14, before GitHub retired those runners),
/// and Metal on iPhones and iPads (not the simulator), for apps that ask for
/// it. On one iPhone 15 Pro (iOS 27) the GPU did the work: the same
/// transcript as the CPU, about 1.7x faster per clip, about 578 MB held on
/// Metal, and about 4.6 s to create (0.6 s on the CPU). No other iPhone,
/// iPad or iOS version has been tested.
const transcriberGpuTargets = <String, String?>{
  'macos/arm64': '14.0',
  'ios/arm64': '15.0',
};

/// Where Audio Transcriber runs: Google's audio library on 64-bit Android,
/// iOS 15+, macOS 14+ arm64, Linux x64 and Windows x64, and through Google's
/// browser runtime where the web plugin installs it, on the CPU everywhere and
/// on the GPU on [transcriberGpuTargets] and in Chromium and WebKit on a Mac's
/// Apple WebGPU adapter.
Future<TaskCapabilities> queryAudioTranscriberCapabilities() async =>
    audioTranscriberCapabilitiesForPlatform(await currentTaskPlatform());

/// Audio Transcriber support on [platform], without loading code.
TaskCapabilities audioTranscriberCapabilitiesForPlatform(
  TaskPlatform platform,
) {
  final targets = _speechTargets();
  final String gpuReason;
  if (!targets.containsKey(platform.target)) {
    gpuReason = _speechUnavailable(platform);
  } else if (platform.operatingSystem == 'web') {
    gpuReason = hasHardwareWebGpu(platform)
        ? '$_transcriberWebGpuUnproved This browser has ${platform.gpu} on '
              '${platform.browserEngine?.name ?? 'an unknown engine'}'
              '${browserOnMac ? ' on a Mac' : ''}.'
        : _transcriberNoWebGpu(platform);
  } else {
    gpuReason = _transcriberGpuUnproved;
  }
  return TaskCapabilities.onTargets(
    platform: platform,
    delegates: {
      Delegate.cpu: targets,
      Delegate.gpu: {
        if (!platform.simulator) ...transcriberGpuTargets,
        if (audioTranscriberOpener != null && _webGpuProved(platform))
          'web/unknown': null,
      },
    },
    unavailableReasons: {
      Delegate.cpu: _speechUnavailable(platform),
      Delegate.gpu: gpuReason,
    },
    runtimeVersion: tasksRuntimeVersionOn(platform),
  );
}

/// Where Text to Speech's native GPU delegate is offered: Metal on macOS 15
/// and later on arm64, which the package's tests prove with Kokoro on macOS
/// 15, the only version CI runs. Kokoro has never run on macOS 14, so it
/// gets the CPU there. A model with no GPU section, such as Phonon, is
/// refused the GPU when the task is created.
const textToSpeechGpuTargets = <String, String?>{'macos/arm64': '15.0'};

/// Where Text to Speech runs: Google's audio library on 64-bit Android, iOS
/// 15+, macOS 14+ arm64, Linux x64 and Windows x64, and through Google's
/// browser runtime where the web plugin installs it, on the CPU everywhere and
/// on the GPU on [textToSpeechGpuTargets] for a model with a GPU section.
Future<TaskCapabilities> queryTextToSpeechCapabilities() async =>
    textToSpeechCapabilitiesForPlatform(await currentTaskPlatform());

/// Text to Speech support on [platform], without loading code.
TaskCapabilities textToSpeechCapabilitiesForPlatform(TaskPlatform platform) {
  final targets = _speechTargets();
  return TaskCapabilities.onTargets(
    platform: platform,
    delegates: {Delegate.cpu: targets, Delegate.gpu: textToSpeechGpuTargets},
    unavailableReasons: {
      Delegate.cpu: _speechUnavailable(platform),
      Delegate.gpu: !targets.containsKey(platform.target)
          ? _speechUnavailable(platform)
          : platform.operatingSystem == 'web'
          ? _textToSpeechWebGpuUnproved
          : _textToSpeechGpuUnproved,
    },
    runtimeVersion: tasksRuntimeVersionOn(platform),
  );
}

Map<String, String?> _speechTargets() => {
  ...speechRuntimeTargets,
  // A registered opener is Google's browser runtime.
  if (audioTranscriberOpener != null) 'web/unknown': null,
};

String _speechUnavailable(TaskPlatform platform) =>
    platform.operatingSystem == 'web'
    ? _speechNoBrowserPlugin
    : platform.target == 'android/arm'
    ? largeModelNeeds64Bit
    : _speechNoLibrary;

/// Decision Maker's delegate support, queried without loading a model.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import '../models.dart' show DecisionModels;
import 'decision_backend.dart' show decisionBackendFactory;

/// Where Google's C library with Decision Maker runs: core's shared 64-bit
/// targets, from its per-family library (`familyRuntimes`). 32-bit Android
/// cannot hold its models ([largeModelNeeds64Bit]).
const decisionRuntimeTargets = largeModelRuntimeTargets;

/// Why the EmbeddingGemma 2 models are unavailable in WebKit (UP-054).
const embeddingGemma2WebKitUnavailable =
    "In WebKit, the engine of Safari and of every browser on iOS, Google's "
    'browser Decision Maker (@mediapipe/tasks-decision) embeds every '
    'text as zeros with the EmbeddingGemma 2 models, so every option scores '
    'the same (upstream-issues.md UP-054). Use DecisionModels.layaS256, or a '
    'Chromium browser.';

/// Why GLiNER2.5-Decide is unavailable in browsers (UP-055).
const glinerBrowserUnavailable =
    "Google's browser Decision Maker (@mediapipe/tasks-decision) aborts "
    'while it creates the task with either GLiNER2.5-Decide model '
    '(upstream-issues.md UP-055). Use DecisionModels.layaS256 in browsers.';

/// Why Google's browser runtime cannot run [model] in the browser [platform]
/// names, or null when it can.
String? _browserRefusal(TaskPlatform platform, DownloadAsset? model) {
  final sha256 = model?.sha256;
  if (platform.operatingSystem != 'web' || sha256 == null) return null;
  if (platform.browserEngine == BrowserEngine.webkit &&
      (sha256 == DecisionModels.embeddingGemma2Text.sha256 ||
          sha256 == DecisionModels.embeddingGemma2TextVision.sha256)) {
    return embeddingGemma2WebKitUnavailable;
  }
  if (sha256 == DecisionModels.glinerS256.sha256 ||
      sha256 == DecisionModels.glinerS512.sha256) {
    return glinerBrowserUnavailable;
  }
  return null;
}

const _noLibrary =
    "Google's Decision Maker library covers Android arm64 and x86_64, iOS, "
    'macOS arm64, Linux x64 and Windows x64, and browsers run its JavaScript '
    'runtime.';

/// Google's browser runtime fails on the CPU (upstream-issues.md UP-049).
const _browserCpu =
    "Google's browser Decision Maker (@mediapipe/tasks-decision) fails "
    'every evaluation on the CPU delegate (upstream-issues.md UP-049). Use '
    'Delegate.gpu, its WebGPU path, as Google\'s web demo does.';

const _desktopGpu =
    "Google's library runs Decision Maker on the CPU; this package has not "
    'validated its GPU path.';

final _unregistered = pluginNotRegistered('mediapipe_decision');
final _noPlugin = '${_unregistered.message} ${_unregistered.fix}';

String _noWebGpu(TaskPlatform platform) =>
    "Google's browser Decision Maker answers only on a hardware WebGPU "
    'adapter; without one it falls back to its CPU path, where every '
    'evaluation fails (upstream-issues.md UP-049). This browser has '
    '${platform.gpu ?? 'no WebGPU adapter'}.';

/// Query Decision Maker support on this platform without loading a model.
/// Pass [model] to learn where that model runs: neither EmbeddingGemma 2
/// model in WebKit (UP-054), GLiNER2.5-Decide nowhere in browsers (UP-055),
/// and every other pinned model wherever the task runs.
Future<TaskCapabilities> queryDecisionMakerCapabilities([
  DownloadAsset? model,
]) async => decisionMakerCapabilitiesForPlatform(
  await currentTaskPlatform(),
  model: model,
);

/// Decision Maker support on [platform]: the CPU on Google's native
/// libraries, and the GPU in browsers once the plugin registers, since
/// Google's browser runtime fails on the CPU (UP-049). With [model], the
/// support for that model: Google's browser runtime fails with EmbeddingGemma
/// 2 in WebKit (UP-054) and with GLiNER2.5-Decide in every browser (UP-055).
TaskCapabilities decisionMakerCapabilitiesForPlatform(
  TaskPlatform platform, {
  DownloadAsset? model,
}) {
  final web = platform.operatingSystem == 'web';
  final noLibrary = platform.target == 'android/arm'
      ? largeModelNeeds64Bit
      : _noLibrary;
  final browserRuns =
      decisionBackendFactory != null && hasHardwareWebGpu(platform);
  // Where the GPU path would run, the browser's own refusal of this model.
  final browserRefusal = browserRuns ? _browserRefusal(platform, model) : null;
  return TaskCapabilities.onTargets(
    platform: platform,
    delegates: {
      Delegate.cpu: decisionRuntimeTargets,
      Delegate.gpu: {
        if (browserRuns && browserRefusal == null) 'web/unknown': null,
      },
    },
    unavailableReasons: {
      // Without a hardware adapter both delegates end on Google's CPU path.
      Delegate.cpu: !web
          ? noLibrary
          : browserRefusal ??
                (hasHardwareWebGpu(platform)
                    ? _browserCpu
                    : _noWebGpu(platform)),
      Delegate.gpu: web
          ? decisionBackendFactory == null
                ? _noPlugin
                : browserRefusal ?? _noWebGpu(platform)
          : decisionRuntimeTargets.containsKey(platform.target)
          ? _desktopGpu
          : noLibrary,
    },
    runtimeVersion: tasksRuntimeVersionOn(platform),
  );
}

/// Per-task delegate support, queried without loading a model.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import '../models.dart' show TextModels;
import 'text_task_backend.dart' show textTaskBackendFactory;

/// CPU wherever Google's text library or, in browsers, its JavaScript runtime
/// serves the task; every text task runs on the CPU only.
TaskCapabilities _onEveryRuntime(
  TaskPlatform platform, {
  required String gpuUnavailableReason,
  RuntimeTargets targets = tasksRuntimeTargets,
}) => TaskCapabilities.cpuOnTargets(
  platform: platform,
  gpuUnavailableReason: gpuUnavailableReason,
  runtimeVersion: tasksRuntimeVersionOn(platform),
  targets: {
    ...targets,
    if (textTaskBackendFactory != null) 'web/unknown': null,
  },
);

const _classicGpu = 'The official classic text tasks run on CPU only.';

/// Google's browser text runtime (`@mediapipe/tasks-text`) has no
/// Proofreader or Summarizer; see upstream-issues.md UP-034.
const _noBrowserGenerativeTasks =
    "Google's browser text runtime has no Proofreader or Summarizer "
    '(upstream-issues.md UP-034). Run the task on Android, iOS, macOS, '
    'Linux or Windows.';

/// The Proofreader and Summarizer: CPU wherever Google's text library serves
/// them (Android, iOS, macOS, Linux and Windows); browsers have neither
/// task.
TaskCapabilities _generative(TaskPlatform platform) {
  const gpu = "Google's task accepts only the CPU delegate.";
  const targets = largeModelRuntimeTargets;
  if (platform.operatingSystem == 'web') {
    return TaskCapabilities.onTargets(
      platform: platform,
      delegates: {Delegate.cpu: targets, Delegate.gpu: const {}},
      unavailableReasons: const {
        Delegate.cpu: _noBrowserGenerativeTasks,
        Delegate.gpu: _noBrowserGenerativeTasks,
      },
      runtimeVersion: tasksRuntimeVersionOn(platform),
    );
  }
  return TaskCapabilities.cpuOnTargets(
    platform: platform,
    gpuUnavailableReason: gpu,
    runtimeVersion: tasksRuntimeVersionOn(platform),
    targets: targets,
  );
}

/// Query Text Classifier support on this platform without a model.
Future<TaskCapabilities> queryTextClassifierCapabilities() async =>
    textClassifierCapabilitiesForPlatform(await currentTaskPlatform());

/// Text Classifier support on [platform]: CPU on Google's text library and
/// the registered browser backend.
TaskCapabilities textClassifierCapabilitiesForPlatform(TaskPlatform platform) =>
    _onEveryRuntime(platform, gpuUnavailableReason: _classicGpu);

/// Query Language Detector support on this platform without a model.
Future<TaskCapabilities> queryLanguageDetectorCapabilities() async =>
    languageDetectorCapabilitiesForPlatform(await currentTaskPlatform());

/// Language Detector support on [platform], as for the Text Classifier.
TaskCapabilities languageDetectorCapabilitiesForPlatform(
  TaskPlatform platform,
) => _onEveryRuntime(platform, gpuUnavailableReason: _classicGpu);

/// Query Text Embedder support on this platform for [model]: pass
/// `TextModels.embeddingGemma` to learn where EmbeddingGemma runs.
Future<TaskCapabilities> queryTextEmbedderCapabilities([
  DownloadAsset? model,
]) async => textEmbedderCapabilitiesForPlatform(
  await currentTaskPlatform(),
  model: model,
);

/// Text Embedder support on [platform]: CPU on Google's text library and the
/// registered browser backend, for the classic embedders and
/// EmbeddingGemma alike, which 32-bit Android cannot hold. Every runtime
/// formats EmbeddingGemma's prompts.
TaskCapabilities textEmbedderCapabilitiesForPlatform(
  TaskPlatform platform, {
  DownloadAsset? model,
}) {
  final embeddingGemma = model?.sha256 == TextModels.embeddingGemma.sha256;
  return _onEveryRuntime(
    platform,
    gpuUnavailableReason: embeddingGemma
        ? "Google's EmbeddingGemma pipeline runs on the CPU only; its macOS "
              'Metal interpreter fails during creation (observed with '
              'MediaPipe 1.0.1).'
        : _classicGpu,
    targets: embeddingGemma ? largeModelRuntimeTargets : tasksRuntimeTargets,
  );
}

/// Query Proofreader support on this platform without a model.
Future<TaskCapabilities> queryTextProofreaderCapabilities() async =>
    textProofreaderCapabilitiesForPlatform(await currentTaskPlatform());

/// Proofreader support on [platform]: CPU on Google's text library; browsers
/// have no Proofreader.
TaskCapabilities textProofreaderCapabilitiesForPlatform(
  TaskPlatform platform,
) => _generative(platform);

/// Query Summarizer support on this platform without a model.
Future<TaskCapabilities> queryTextSummarizerCapabilities() async =>
    textSummarizerCapabilitiesForPlatform(await currentTaskPlatform());

/// Summarizer support on [platform]: CPU on Google's text library; browsers
/// have no Summarizer.
TaskCapabilities textSummarizerCapabilitiesForPlatform(TaskPlatform platform) =>
    _generative(platform);

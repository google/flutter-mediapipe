/// Audio Classifier's delegate support, queried without loading a model.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import 'audio_task_backend.dart' show audioTaskBackendFactory;

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

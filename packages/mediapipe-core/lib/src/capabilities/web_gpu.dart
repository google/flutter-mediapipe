import 'task_capabilities.dart';

/// How `readWebGpuAdapter` names a browser's WebGPU adapter in
/// [TaskPlatform.gpu].
const webGpuAdapterPrefix = 'WebGPU';

/// The adapters Google's browser runtimes refuse to run on, by Google's own
/// rule.
final _softwareAdapter = RegExp(
  r'fallback|swiftshader|llvmpipe|software|lavapipe',
  caseSensitive: false,
);

/// Whether [platform] names a hardware WebGPU adapter, the only one Google's
/// browser Decision Maker answers on (UP-049) and its Universal Embedder runs
/// on (UP-052).
bool hasHardwareWebGpu(TaskPlatform platform) => switch (platform.gpu) {
  final gpu? =>
    gpu.startsWith(webGpuAdapterPrefix) && !_softwareAdapter.hasMatch(gpu),
  null => false,
};

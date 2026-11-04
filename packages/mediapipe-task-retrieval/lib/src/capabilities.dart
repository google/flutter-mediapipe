/// The retrieval tasks' delegate support, queried without loading a model.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import 'retrieval_backend.dart' show retrievalBackendFactory;

/// Where Google's retrieval library runs: core's shared 64-bit targets,
/// which Google's per-family build covers as its vision, text and audio
/// libraries do. 32-bit Android cannot hold its models
/// ([largeModelNeeds64Bit]).
const retrievalRuntimeTargets = largeModelRuntimeTargets;

const _desktopGpu =
    "Google's retrieval library runs the tasks on the CPU; this package has "
    'not validated a GPU path.';

/// Why a native target outside [retrievalRuntimeTargets] runs neither task.
const _noLibrary =
    "Google's retrieval library covers Android arm64 and x86_64, iOS, macOS "
    'arm64, Linux x64 and Windows x64, and browsers run its JavaScript '
    'runtime.';

final _unregistered = pluginNotRegistered('mediapipe_retrieval');
final _noPlugin = '${_unregistered.message} ${_unregistered.fix}';

/// Google's browser Universal Embedder creates a WebGPU device for itself
/// and has no CPU path (upstream-issues.md UP-052).
const _browserCpu =
    "Google's browser Universal Embedder (@mediapipe/tasks-retrieval) "
    'runs on a WebGPU device only (upstream-issues.md UP-052). Use '
    'Delegate.gpu.';

String _noWebGpu(TaskPlatform platform) =>
    "Google's browser Universal Embedder runs only on a hardware WebGPU "
    'adapter: it creates a WebGPU device for itself and refuses a software '
    'one (upstream-issues.md UP-052). This browser has '
    '${platform.gpu ?? 'no WebGPU adapter'}.';

/// Why both tasks are unavailable in WebKit (UP-054).
const embeddingGemma2WebKitUnavailable =
    "In WebKit, the engine of Safari and of every browser on iOS, Google's "
    'browser Universal Embedder (@mediapipe/tasks-retrieval) returns '
    'zeros for every input with both EmbeddingGemma 2 models, so no document '
    'matches any query (upstream-issues.md UP-054). Use a Chromium browser.';

/// Both tasks' support on [platform]: the CPU on Google's retrieval library
/// natively, and the GPU in browsers once the plugin registers, on a hardware
/// WebGPU adapter only, since Google's browser runtime has no CPU path, and
/// not in WebKit, where it embeds everything as zeros (UP-054).
TaskCapabilities _capabilities(TaskPlatform platform) {
  final web = platform.operatingSystem == 'web';
  final noLibrary = platform.target == 'android/arm'
      ? largeModelNeeds64Bit
      : _noLibrary;
  final browserRuns =
      retrievalBackendFactory != null && hasHardwareWebGpu(platform);
  final webKit = platform.browserEngine == BrowserEngine.webkit;
  return TaskCapabilities.onTargets(
    platform: platform,
    delegates: {
      Delegate.cpu: retrievalRuntimeTargets,
      Delegate.gpu: {if (browserRuns && !webKit) 'web/unknown': null},
    },
    unavailableReasons: {
      // Without a hardware adapter both delegates end on Google's WebGPU check.
      Delegate.cpu: !web
          ? noLibrary
          : browserRuns && webKit
          ? embeddingGemma2WebKitUnavailable
          : hasHardwareWebGpu(platform)
          ? _browserCpu
          : _noWebGpu(platform),
      Delegate.gpu: web
          ? retrievalBackendFactory == null
                ? _noPlugin
                : browserRuns && webKit
                ? embeddingGemma2WebKitUnavailable
                : _noWebGpu(platform)
          : retrievalRuntimeTargets.containsKey(platform.target)
          ? _desktopGpu
          : noLibrary,
    },
    runtimeVersion: tasksRuntimeVersionOn(platform),
  );
}

/// Query Universal Embedder support on this platform without a model.
Future<TaskCapabilities> queryUniversalEmbedderCapabilities() async =>
    universalEmbedderCapabilitiesForPlatform(await currentTaskPlatform());

/// Universal Embedder support on [platform]: the CPU on Google's retrieval
/// library, and in browsers the GPU on a hardware WebGPU adapter.
TaskCapabilities universalEmbedderCapabilitiesForPlatform(
  TaskPlatform platform,
) => _capabilities(platform);

/// Query Semantic Retriever support on this platform without a model.
Future<TaskCapabilities> querySemanticRetrieverCapabilities() async =>
    semanticRetrieverCapabilitiesForPlatform(await currentTaskPlatform());

/// Semantic Retriever support on [platform], as for the embedder it runs on.
TaskCapabilities semanticRetrieverCapabilitiesForPlatform(
  TaskPlatform platform,
) => _capabilities(platform);

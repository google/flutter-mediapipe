/// What the family packages and platform plugins need from core and apps do
/// not: model resolution, the runtime tables behind the capability queries,
/// the checks every family shares, and the host details of Google's C API.
///
/// Applications should import a family's library instead.
library;

export 'src/capabilities/platform_stub.dart'
    if (dart.library.io) 'src/capabilities/platform_io.dart';
export 'src/capabilities/task_capabilities.dart'
    show
        largeModelNeeds64Bit,
        largeModelRuntimeTargets,
        pluginNotRegistered,
        requireDelegate,
        taskPlatformGpuReader,
        tasksRuntimeTargets,
        tasksRuntimeUnavailable,
        tasksRuntimeVersionOn;
export 'src/capabilities/web_gpu.dart' show hasHardwareWebGpu;
export 'src/classifier_settings.dart';
export 'src/host_stub.dart' if (dart.library.io) 'src/host_io.dart';
export 'src/model_source.dart';
export 'src/pinned_model.dart';
export 'src/sdk_json.dart';
export 'src/serial_task_queue.dart';
export 'src/stream_timestamps.dart';
export 'src/task_options.dart' show holdModelBytes, resolveTaskModel;
export 'src/value_types.dart' show cosineSimilarity;

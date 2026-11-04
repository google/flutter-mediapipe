import 'package:web/web.dart' as web;

import 'task_capabilities.dart';

Future<TaskPlatform>? _platform;

/// Web has no packaged native task runtime. The GPU is what a registered
/// plugin's [taskPlatformGpuReader] names, such as the browser's WebGPU
/// adapter, read once; the engine is what the user agent names.
Future<TaskPlatform> currentTaskPlatform() => _platform ??= _readPlatform();

Future<TaskPlatform> _readPlatform() async => TaskPlatform(
  operatingSystem: 'web',
  architecture: 'unknown',
  gpu: await readTaskPlatformGpu(),
  browserEngine: BrowserEngine.fromUserAgent(web.window.navigator.userAgent),
);

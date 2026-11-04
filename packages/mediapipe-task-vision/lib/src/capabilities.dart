/// Query per-task delegate support without loading a model.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';
import 'vision_task_backend.dart';

/// Why the iOS Simulator offers the CPU only: Google's MediaPipe aborts the
/// app there as soon as a GPU task processes an image, which no caller can
/// catch.
/// Devices keep the GPU.
const _simulatorGpuGap =
    "Google's MediaPipe aborts the app on the iOS Simulator's GPU (Metal) path; "
    'use the CPU delegate on the simulator. iPhones and iPads run the GPU. See '
    'upstream-issues.md UP-031.';

/// Why an Android emulator offers the CPU only: it renders OpenGL ES in
/// software (SwiftShader), where Google's GPU inference fails, through its
/// Android SDK as through its C library. Phones keep the GPU.
String? _emulatorGpuGap(TaskPlatform platform) =>
    platform.operatingSystem == 'android' &&
        (platform.gpu?.toLowerCase().contains('swiftshader') ?? false)
    ? 'This Android emulator renders OpenGL ES in software (SwiftShader), '
          "where Google's GPU inference fails; use the CPU delegate. Phones "
          'run the GPU.'
    : null;

/// Why Face Detector offers no GPU on Linux and Android: since 1.1.0 its GPU
/// inference runs on LiteRT, which loads its GPU backend from a plugin
/// (`libLiteRtGpuAccelerator.so` and its OpenCL, Vulkan and WebGPU
/// variants) that Google's Linux and Android libraries look for but do not
/// ship. Apple's builds carry Metal, and the other tasks' GPU paths do not
/// use LiteRT.
const _faceDetectorGpuGap =
    "Google's Linux and Android libraries do not ship the LiteRT GPU plugin "
    "that Face Detector's GPU needs (libLiteRtGpuAccelerator.so); use the "
    'CPU delegate. Face Landmarker runs on the GPU there. See '
    'upstream-issues.md UP-046.';

/// Why macOS offers the CPU only: on Metal, Google's library since 1.1.1
/// differs from Google's own 1.1.0 wheel for every task, by up to a
/// different top class, and its 1.1.1 nightly wheel matches the library
/// where compared; Google is checking whether the change is intended. The
/// CPU matches the 1.1.0 wheel exactly.
/// The tasks keep `macosGpu`, which names the ones that return once Google
/// confirms the new output (UP-057).
/// 32-bit Android (armeabi-v7a) runs the vision tasks on the CPU; this
/// package has not validated Google's GPU path there.
const _arm32GpuGap =
    "The GPU on 32-bit Android (armeabi-v7a) is not validated; the vision "
    'tasks run there on the CPU.';

const _macosGpuGap =
    "Since 1.1.1, Google's macOS library gives different results on Metal "
    "from Google's own 1.1.0 package, and Google is checking whether that is "
    'intended; use the CPU delegate, which matches that package exactly. See '
    'upstream-issues.md UP-057.';

/// Query official FaceLandmarker platform support without creating a task.
Future<TaskCapabilities> queryFaceLandmarkerCapabilities() async =>
    faceLandmarkerCapabilitiesForPlatform(await currentTaskPlatform());

/// Face Landmarker: CPU on Google's vision library on Android, iOS, macOS,
/// Linux and Windows, and the registered web adapter; GPU everywhere but
/// Windows, macOS ([_macosGpuGap]) and the iOS Simulator.
TaskCapabilities faceLandmarkerCapabilitiesForPlatform(TaskPlatform platform) =>
    _visionTaskCapabilities(
      platform,
      'FaceLandmarker',
      webAdapter: faceLandmarkerBackendFactory != null,
      linuxGpu: true,
      macosGpu: true,
    );

/// Query Face Detector support on this process platform without a model.
Future<TaskCapabilities> queryFaceDetectorCapabilities() async =>
    faceDetectorCapabilitiesForPlatform(await currentTaskPlatform());

/// Face Detector runs where Face Landmarker does, except on the Linux and
/// Android GPU ([_faceDetectorGpuGap]).
TaskCapabilities faceDetectorCapabilitiesForPlatform(TaskPlatform platform) =>
    _visionTaskCapabilities(
      platform,
      'FaceDetector',
      webAdapter: faceDetectorBackendFactory != null,
      macosGpu: true,
      desktopGpuGap: _faceDetectorGpuGap,
      androidGpuGap: _faceDetectorGpuGap,
    );

/// Query Hand Landmarker support on this process platform without a model.
Future<TaskCapabilities> queryHandLandmarkerCapabilities() async =>
    handLandmarkerCapabilitiesForPlatform(await currentTaskPlatform());

/// Hand Landmarker runs where Face Landmarker does.
TaskCapabilities handLandmarkerCapabilitiesForPlatform(TaskPlatform platform) =>
    _visionTaskCapabilities(
      platform,
      'HandLandmarker',
      webAdapter: handLandmarkerBackendFactory != null,
      linuxGpu: true,
      macosGpu: true,
    );

/// Query Pose Landmarker support on this process platform without a model.
Future<TaskCapabilities> queryPoseLandmarkerCapabilities() async =>
    poseLandmarkerCapabilitiesForPlatform(await currentTaskPlatform());

/// Pose Landmarker runs where Face Landmarker does.
TaskCapabilities poseLandmarkerCapabilitiesForPlatform(TaskPlatform platform) =>
    _visionTaskCapabilities(
      platform,
      'PoseLandmarker',
      webAdapter: poseLandmarkerBackendFactory != null,
      linuxGpu: true,
      macosGpu: true,
    );

/// Query Gesture Recognizer support on this process platform without a model.
Future<TaskCapabilities> queryGestureRecognizerCapabilities() async =>
    gestureRecognizerCapabilitiesForPlatform(await currentTaskPlatform());

/// Gesture Recognizer runs where Face Landmarker does.
TaskCapabilities gestureRecognizerCapabilitiesForPlatform(
  TaskPlatform platform,
) => _visionTaskCapabilities(
  platform,
  'GestureRecognizer',
  webAdapter: gestureRecognizerBackendFactory != null,
  linuxGpu: true,
  macosGpu: true,
);

/// Query Holistic Landmarker support on this process platform without a model.
Future<TaskCapabilities> queryHolisticLandmarkerCapabilities() async =>
    holisticLandmarkerCapabilitiesForPlatform(await currentTaskPlatform());

/// Holistic Landmarker runs on the CPU where Face Landmarker does; its GPU
/// runs in browsers only, since Google's libraries cannot open its face
/// blendshapes model on a desktop, iPhone or Android GPU (UP-026).
TaskCapabilities holisticLandmarkerCapabilitiesForPlatform(
  TaskPlatform platform,
) => _visionTaskCapabilities(
  platform,
  'HolisticLandmarker',
  webAdapter: holisticLandmarkerBackendFactory != null,
  desktopGpuGap:
      'Google\'s desktop runtimes cannot open its face blendshapes model on '
      'GPU (upstream-issues.md UP-026).',
  iosGpuGap:
      'Google\'s iOS library cannot open its face blendshapes model on the '
      'GPU (upstream-issues.md UP-026).',
  androidGpuGap:
      'Google\'s Android library cannot open its face blendshapes model on '
      'the GPU (upstream-issues.md UP-026).',
);

/// CPU on Google's vision library (Android, iOS, macOS arm64, Linux x64 and
/// Windows x64) and the registered web adapter; GPU on iOS, Android and the
/// web, and with [linuxGpu] on Linux (OpenGL ES, needing EGL and a GPU
/// driver). [macosGpu] marks the tasks that run on Metal, which macOS
/// withdraws for now ([_macosGpuGap]). An [androidGpuGap] withdraws the
/// Android GPU and is the reason an Android device reports, except on an
/// emulator, which loses the GPU for every task ([_emulatorGpuGap]); an
/// [iosGpuGap] withdraws an iPhone's GPU the same way, and the iOS Simulator
/// always loses the GPU ([_simulatorGpuGap]).
TaskCapabilities _visionTaskCapabilities(
  TaskPlatform platform,
  String name, {
  required bool webAdapter,
  bool linuxGpu = false,
  bool macosGpu = false,
  String? desktopGpuGap,
  String? androidGpuGap,
  String? iosGpuGap,
}) {
  final androidGap = _emulatorGpuGap(platform) ?? androidGpuGap;
  return TaskCapabilities.onTargets(
    platform: platform,
    delegates: {
      Delegate.cpu: {
        'linux/x64': null,
        'windows/x64': null,
        'macos/arm64': '14.0',
        'ios/arm64': '15.0',
        'android/arm64': null,
        // 32-bit Arm (armeabi-v7a): Google's library for it, on the CPU.
        'android/arm': null,
        // Google's library ships x86_64; the emulator CI job runs it on the
        // CPU.
        'android/x64': null,
        if (webAdapter) 'web/unknown': null,
      },
      Delegate.gpu: {
        if (linuxGpu) 'linux/x64': null,
        if (!platform.simulator && iosGpuGap == null) 'ios/arm64': '15.0',
        if (androidGap == null) 'android/arm64': null,
        if (webAdapter) 'web/unknown': null,
      },
    },
    runtimeVersion: tasksRuntimeVersionOn(platform),
    unavailableReasons: {
      Delegate.cpu:
          '$name requires Linux x64, Windows x64, macOS arm64, iOS, '
          'Android, or the web adapter package.',
      Delegate.gpu:
          (platform.target == 'android/arm' ? _arm32GpuGap : null) ??
          (platform.operatingSystem == 'android' ? androidGap : null) ??
          (platform.simulator ? _simulatorGpuGap : null) ??
          (platform.operatingSystem == 'ios' ? iosGpuGap : null) ??
          (platform.operatingSystem == 'macos' && macosGpu
              ? _macosGpuGap
              : null) ??
          [
            '$name GPU requires ${_either([if (linuxGpu) 'Linux x64', if (iosGpuGap == null) 'iOS', if (androidGpuGap == null) 'Android', 'the web adapter'])}.',
            ?desktopGpuGap,
          ].join(' '),
    },
  );
}

/// [items] as an English list ending in "or": `a`, `a or b`, `a, b, or c`.
String _either(List<String> items) => switch (items) {
  [final only] => only,
  [final first, final second] => '$first or $second',
  _ => '${items.take(items.length - 1).join(', ')}, or ${items.last}',
};

/// Query Image Segmenter support on this process platform without a model.
Future<TaskCapabilities> queryImageSegmenterCapabilities() async =>
    imageSegmenterCapabilitiesForPlatform(await currentTaskPlatform());

/// Why Image Segmenter offers no GPU on Android: Google's Android task aborts
/// the app when it reads a GPU mask on a PowerVR GPU and on a Pixel 3's
/// Adreno 630, in its Java SDK and its C library alike, which no caller can
/// catch (upstream-issues.md UP-061 and UP-023).
const _androidSegmenterGpuGap =
    "Google's Android Image Segmenter aborts the app when it reads a GPU "
    'mask on PowerVR and Adreno 630 GPUs, in its Java SDK and its C library '
    'alike, which no caller can catch; use the CPU delegate. See '
    'upstream-issues.md UP-061 and UP-023.';

/// Image Segmenter, declared as [imageClassifierCapabilitiesForPlatform],
/// except on Android, where only the CPU is offered
/// ([_androidSegmenterGpuGap]).
TaskCapabilities imageSegmenterCapabilitiesForPlatform(TaskPlatform platform) =>
    _visionTaskCapabilities(
      platform,
      'ImageSegmenter',
      webAdapter: imageSegmenterBackendFactory != null,
      linuxGpu: true,
      macosGpu: true,
      androidGpuGap: _androidSegmenterGpuGap,
    );

/// Query Image Classifier support on this process platform without a model.
Future<TaskCapabilities> queryImageClassifierCapabilities() async =>
    imageClassifierCapabilitiesForPlatform(await currentTaskPlatform());

/// Image Classifier runs where Face Landmarker does.
TaskCapabilities imageClassifierCapabilitiesForPlatform(
  TaskPlatform platform,
) => _visionTaskCapabilities(
  platform,
  'ImageClassifier',
  webAdapter: imageClassifierBackendFactory != null,
  linuxGpu: true,
  macosGpu: true,
);

/// Query Image Embedder support on this process platform without a model.
Future<TaskCapabilities> queryImageEmbedderCapabilities() async =>
    imageEmbedderCapabilitiesForPlatform(await currentTaskPlatform());

/// Image Embedder runs where Face Landmarker does, except on the Linux GPU.
TaskCapabilities imageEmbedderCapabilitiesForPlatform(TaskPlatform platform) =>
    _visionTaskCapabilities(
      platform,
      'ImageEmbedder',
      webAdapter: imageEmbedderBackendFactory != null,
      macosGpu: true,
      desktopGpuGap:
          'Google\'s Linux runtime aborts on GPU (upstream-issues.md UP-027).',
    );

/// Describe the package's stateful MagicTouch support on this process platform.
Future<TaskCapabilities> queryInteractiveSegmenterCapabilities() async =>
    interactiveSegmenterCapabilitiesForPlatform(await currentTaskPlatform());

/// Evaluate support for an explicit process platform snapshot: CPU on Google's
/// vision library on Android, iOS, macOS and Linux, and the web adapter.
/// Google's Windows library exports the stateful API too, but a stroke takes
/// about 25 seconds on it (upstream-issues.md UP-048), so Windows stays off.
TaskCapabilities interactiveSegmenterCapabilitiesForPlatform(
  TaskPlatform platform,
) {
  final adapter = interactiveSegmenterBackendFactory != null;
  return TaskCapabilities.onTargets(
    platform: platform,
    delegates: {
      Delegate.cpu: {
        'macos/arm64': '14.0',
        // Google's Linux library exports the stateful API.
        'linux/x64': null,
        'ios/arm64': '15.0',
        'android/arm64': null,
        'android/arm': null,
        'android/x64': null,
        if (adapter) 'web/unknown': null,
      },
      // Google's browser task runs MagicTouch on WebGL 2, as its sample does
      // by default. Its mobile SDKs run it on CPU.
      Delegate.gpu: {if (adapter) 'web/unknown': null},
    },
    runtimeVersion: tasksRuntimeVersionOn(platform),
    unavailableReasons: {
      Delegate.cpu:
          'InteractiveSegmenter requires macOS arm64, Linux x64, iOS, '
          "Android, or the web adapter package. Google's Windows library "
          'runs it too slowly to offer (upstream-issues.md UP-048).',
      Delegate.gpu: platform.operatingSystem == 'macos'
          ? 'The official MediaPipe macOS GPU stroke shader requests GLSL 330 in '
                'an OpenGL 2.1 context and fails to compile. Confirmed on both '
                'the 1.0.0 and 1.0.1 official runtimes, so it is not fixed by '
                'changing version. Metal itself is fine; only GL-shader '
                'calculators are affected. This task supports CPU only (see '
                'upstream-issues.md UP-008).'
          : 'Interactive Segmenter GPU runs in browsers only; elsewhere it '
                'supports CPU only.',
    },
  );
}

/// Describe the package's Object Detector support on this process platform.
Future<TaskCapabilities> queryObjectDetectorCapabilities() async =>
    objectDetectorCapabilitiesForPlatform(await currentTaskPlatform());

/// Object Detector runs where Face Landmarker does.
TaskCapabilities objectDetectorCapabilitiesForPlatform(TaskPlatform platform) =>
    _visionTaskCapabilities(
      platform,
      'ObjectDetector',
      webAdapter: objectDetectorBackendFactory != null,
      linuxGpu: true,
      macosGpu: true,
    );

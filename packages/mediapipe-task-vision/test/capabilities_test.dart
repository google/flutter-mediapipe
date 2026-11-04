import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';

const _arm32 = TaskPlatform(operatingSystem: 'android', architecture: 'arm');

void main() {
  test('32-bit Android runs the vision tasks on the CPU only', () {
    for (final capabilities in [
      faceDetectorCapabilitiesForPlatform(_arm32),
      handLandmarkerCapabilitiesForPlatform(_arm32),
      imageSegmenterCapabilitiesForPlatform(_arm32),
      interactiveSegmenterCapabilitiesForPlatform(_arm32),
    ]) {
      expect(capabilities.supportedDelegates, {Delegate.cpu});
    }
    expect(
      faceDetectorCapabilitiesForPlatform(
        _arm32,
      ).unavailableReasons[Delegate.gpu],
      contains('32-bit Android'),
    );
  });

  test('Hand Landmarker follows each official runtime and adapter', () {
    TaskPlatform platform(String os, String architecture, [String? version]) =>
        TaskPlatform(
          operatingSystem: os,
          architecture: architecture,
          version: version,
        );
    const both = {Delegate.cpu, Delegate.gpu};
    // Google's Linux library runs the GPU; its Windows library has none.
    expect(
      handLandmarkerCapabilitiesForPlatform(
        platform('linux', 'x64'),
      ).supportedDelegates,
      both,
    );
    expect(
      handLandmarkerCapabilitiesForPlatform(
        platform('windows', 'x64'),
      ).supportedDelegates,
      {Delegate.cpu},
    );
    // macOS 14 and iOS 15 or later, where Google's vision library runs; macOS
    // on the CPU only for now (UP-057).
    expect(
      handLandmarkerCapabilitiesForPlatform(
        platform('macos', 'arm64', '14.0'),
      ).supportedDelegates,
      {Delegate.cpu},
    );
    expect(
      handLandmarkerCapabilitiesForPlatform(
        platform('macos', 'arm64', '13.6'),
      ).isSupported,
      isFalse,
    );
    final ios = handLandmarkerCapabilitiesForPlatform(
      platform('ios', 'arm64', '15.0'),
    );
    expect(ios.supportedDelegates, both);
    expect(ios.runtimeVersion, '1.2.0');
    // Android runs Google's vision library: GPU on arm64 phones, and CPU on
    // the x86_64 emulator images.
    expect(
      handLandmarkerCapabilitiesForPlatform(
        platform('android', 'arm64'),
      ).supportedDelegates,
      both,
    );
    final emulator = handLandmarkerCapabilitiesForPlatform(
      platform('android', 'x64'),
    );
    expect(emulator.supportedDelegates, {Delegate.cpu});
    expect(emulator.runtimeVersion, '1.2.0');
    // The web needs its registered adapter, absent here.
    final web = handLandmarkerCapabilitiesForPlatform(
      platform('web', 'unknown'),
    );
    expect(web.isSupported, isFalse);
    expect(web.unavailableReasons[Delegate.cpu], contains('adapter'));
  });

  test('MagicTouch reports its own GPU shader blocker', () {
    const mac = TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '14.0',
    );
    final result = interactiveSegmenterCapabilitiesForPlatform(mac);
    expect(result.supportedDelegates, {Delegate.cpu});
    expect(result.unavailableReasons[Delegate.gpu], contains('GLSL 330'));
    expect(result.runtimeVersion, '1.2.0');
  });

  test("MagicTouch stays off Google's Windows library, with the reason", () {
    final windows = interactiveSegmenterCapabilitiesForPlatform(
      const TaskPlatform(operatingSystem: 'windows', architecture: 'x64'),
    );
    expect(windows.isSupported, isFalse);
    expect(windows.unavailableReasons[Delegate.cpu], contains('UP-048'));
  });

  test('macOS offers the CPU only, with the reason (UP-057)', () {
    // Google's library since 1.1.1 gives different Metal results from its
    // 1.1.0 wheel, so every task that ran on Metal reports the withdrawal;
    // Holistic and MagicTouch keep their own, older reasons.
    const mac = TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '14.0',
    );
    for (final claim in [
      faceDetectorCapabilitiesForPlatform,
      faceLandmarkerCapabilitiesForPlatform,
      handLandmarkerCapabilitiesForPlatform,
      poseLandmarkerCapabilitiesForPlatform,
      gestureRecognizerCapabilitiesForPlatform,
      imageClassifierCapabilitiesForPlatform,
      imageEmbedderCapabilitiesForPlatform,
      imageSegmenterCapabilitiesForPlatform,
      objectDetectorCapabilitiesForPlatform,
    ]) {
      final result = claim(mac);
      expect(result.supportedDelegates, {Delegate.cpu});
      expect(result.unavailableReasons[Delegate.gpu], contains('UP-057'));
    }
    expect(
      holisticLandmarkerCapabilitiesForPlatform(
        mac,
      ).unavailableReasons[Delegate.gpu],
      contains('UP-026'),
    );
    expect(objectDetectorCapabilitiesForPlatform(mac).runtimeVersion, '1.2.0');
  });

  test('Face Landmarker offers GPU on Linux x64, not Windows', () {
    TaskCapabilities on(String os) => faceLandmarkerCapabilitiesForPlatform(
      TaskPlatform(operatingSystem: os, architecture: 'x64'),
    );
    expect(on('linux').supportedDelegates, {Delegate.cpu, Delegate.gpu});
    expect(on('windows').supportedDelegates, {Delegate.cpu});
    expect(on('windows').unavailableReasons[Delegate.gpu], isNotNull);
  });

  test("Linux and Windows report Google's 1.2.0 libraries", () {
    for (final (os, version) in [('linux', '1.2.0'), ('windows', '1.2.0')]) {
      final platform = TaskPlatform(operatingSystem: os, architecture: 'x64');
      for (final result in [
        faceLandmarkerCapabilitiesForPlatform(platform),
        poseLandmarkerCapabilitiesForPlatform(platform),
        imageSegmenterCapabilitiesForPlatform(platform),
        imageClassifierCapabilitiesForPlatform(platform),
        objectDetectorCapabilitiesForPlatform(platform),
      ]) {
        expect(result.runtimeVersion, version);
      }
    }
  });

  test('an unsupported platform fails closed for both delegates', () {
    final result = objectDetectorCapabilitiesForPlatform(
      const TaskPlatform(
        operatingSystem: 'linux',
        architecture: 'arm64',
        version: '1.0',
      ),
    );
    expect(result.supportedDelegates, isEmpty);
    expect(result.isSupported, isFalse);
    // The platform itself is the blocker, so it explains both delegates.
    expect(result.unavailableReasons[Delegate.cpu], isNotNull);
    expect(result.unavailableReasons[Delegate.gpu], isNotNull);
  });

  test('Object Detector desktop x64: Linux GPU, Windows CPU only', () {
    final linux = objectDetectorCapabilitiesForPlatform(
      const TaskPlatform(operatingSystem: 'linux', architecture: 'x64'),
    );
    expect(linux.supportedDelegates, {Delegate.cpu, Delegate.gpu});
    final windows = objectDetectorCapabilitiesForPlatform(
      const TaskPlatform(operatingSystem: 'windows', architecture: 'x64'),
    );
    expect(windows.supportedDelegates, {Delegate.cpu});
    expect(windows.unavailableReasons[Delegate.gpu], contains('Linux'));
    expect(
      windows.supportedTargets.keys,
      containsAll(['linux/x64', 'windows/x64']),
    );
  });

  test('desktop GPU where Google\'s desktop runtimes run the task', () {
    const linux = TaskPlatform(operatingSystem: 'linux', architecture: 'x64');
    const windows = TaskPlatform(
      operatingSystem: 'windows',
      architecture: 'x64',
    );
    const macos = TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '15.0',
    );
    // macOS offers no GPU for now (UP-057).
    for (final (claim, onLinux) in [
      (poseLandmarkerCapabilitiesForPlatform, true),
      (gestureRecognizerCapabilitiesForPlatform, true),
      (imageClassifierCapabilitiesForPlatform, true),
      (imageSegmenterCapabilitiesForPlatform, true),
      // UP-027: Google's Linux runtime aborts the embedder on GPU.
      (imageEmbedderCapabilitiesForPlatform, false),
      // UP-026: neither runtime opens Holistic's blendshapes model on GPU.
      (holisticLandmarkerCapabilitiesForPlatform, false),
      // UP-046: Google's Linux library lacks Face Detector's LiteRT GPU plugin.
      (faceDetectorCapabilitiesForPlatform, false),
      (faceLandmarkerCapabilitiesForPlatform, true),
    ]) {
      expect(claim(linux).supportedDelegates.contains(Delegate.gpu), onLinux);
      expect(claim(windows).supportedDelegates, isNot(contains(Delegate.gpu)));
      expect(claim(macos).supportedDelegates, {Delegate.cpu});
    }
    expect(
      holisticLandmarkerCapabilitiesForPlatform(
        linux,
      ).unavailableReasons[Delegate.gpu],
      contains('UP-026'),
    );
    expect(
      faceDetectorCapabilitiesForPlatform(
        linux,
      ).unavailableReasons[Delegate.gpu],
      allOf(contains('UP-046'), isNot(contains('Linux x64,'))),
    );
  });

  test(
    'Image Segmenter offers only CPU on every Android GPU (UP-061, UP-023)',
    () {
      TaskPlatform android(String? gpu) => TaskPlatform(
        operatingSystem: 'android',
        architecture: 'arm64',
        gpu: gpu,
      );
      // Google's task aborted the app on PowerVR and on a Pixel 3's Adreno
      // 630, and a GPU nobody has tried may be next.
      for (final gpu in [
        'PowerVR Rogue GE8320 (Imagination Technologies)',
        'Adreno (TM) 630 (Qualcomm)',
        'Mali-G715 (ARM)',
        'Adreno (TM) 750 (Qualcomm)',
        null,
      ]) {
        final capabilities = imageSegmenterCapabilitiesForPlatform(
          android(gpu),
        );
        expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: gpu);
        expect(
          capabilities.unavailableReasons[Delegate.gpu],
          allOf(contains('UP-061'), contains('UP-023')),
        );
      }
      // Only Image Segmenter is withdrawn, and only on Android.
      expect(
        imageClassifierCapabilitiesForPlatform(
          android('PowerVR Rogue GE8320 (Imagination Technologies)'),
        ).supportedDelegates,
        contains(Delegate.gpu),
      );
      const linuxPowerVr = TaskPlatform(
        operatingSystem: 'linux',
        architecture: 'x64',
        gpu: 'PowerVR B-Series BXE-4-32 (Imagination Technologies)',
      );
      expect(
        imageSegmenterCapabilitiesForPlatform(linuxPowerVr).supportedDelegates,
        contains(Delegate.gpu),
      );
    },
  );

  test('an Android emulator rendering on SwiftShader offers the CPU only', () {
    TaskPlatform android(String? gpu) => TaskPlatform(
      operatingSystem: 'android',
      architecture: 'arm64',
      gpu: gpu,
    );
    // As the vision plugin names an arm64 emulator's GPU on an Apple silicon
    // Mac.
    final emulator = android(
      'Android Emulator OpenGL ES Translator (ANGLE (Google, Vulkan 1.3.0 '
      '(SwiftShader Device (LLVM 10.0.0) (0x0000C0DE)), SwiftShader '
      'driver-5.0.0)) (Google (Google Inc. (Google)))',
    );
    const phone = 'Adreno (TM) 750 (Qualcomm)';
    final every = <String, TaskCapabilities Function(TaskPlatform)>{
      'face landmarker': faceLandmarkerCapabilitiesForPlatform,
      'face detector': faceDetectorCapabilitiesForPlatform,
      'hand landmarker': handLandmarkerCapabilitiesForPlatform,
      'pose landmarker': poseLandmarkerCapabilitiesForPlatform,
      'gesture recognizer': gestureRecognizerCapabilitiesForPlatform,
      'holistic landmarker': holisticLandmarkerCapabilitiesForPlatform,
      'image classifier': imageClassifierCapabilitiesForPlatform,
      'image embedder': imageEmbedderCapabilitiesForPlatform,
      'image segmenter': imageSegmenterCapabilitiesForPlatform,
      'object detector': objectDetectorCapabilitiesForPlatform,
    };
    // Withdrawn on every Android GPU, phones included (UP-046, UP-026,
    // UP-061).
    const phoneCpuOnly = {
      'face detector',
      'holistic landmarker',
      'image segmenter',
    };
    for (final MapEntry(key: name, value: claim) in every.entries) {
      final capabilities = claim(emulator);
      expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: name);
      expect(
        capabilities.unavailableReasons[Delegate.gpu],
        contains('SwiftShader'),
        reason: name,
      );
      if (phoneCpuOnly.contains(name)) continue;
      // Phones, and a GPU the plugin could not name, keep the GPU.
      for (final gpu in [phone, null]) {
        expect(
          claim(android(gpu)).supportedDelegates,
          contains(Delegate.gpu),
          reason: '$name on $gpu',
        );
      }
    }
  });

  test("Android phones offer Face Detector's and Holistic's CPU only", () {
    // Google's Android library lacks the LiteRT GPU plugin Face Detector's GPU
    // needs (UP-046), and cannot open Holistic's face blendshapes model on the
    // GPU (UP-026). Face Landmarker and the other tasks keep the GPU.
    for (final gpu in [
      'Mali-G715 (ARM)',
      'Adreno (TM) 750 (Qualcomm)',
      'PowerVR D-Series DXT-48-1536 (Imagination Technologies)',
      null,
    ]) {
      final phone = TaskPlatform(
        operatingSystem: 'android',
        architecture: 'arm64',
        gpu: gpu,
      );
      for (final (claim, issue) in [
        (faceDetectorCapabilitiesForPlatform, 'UP-046'),
        (holisticLandmarkerCapabilitiesForPlatform, 'UP-026'),
      ]) {
        final capabilities = claim(phone);
        expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: gpu);
        expect(
          capabilities.unavailableReasons[Delegate.gpu],
          contains(issue),
          reason: gpu,
        );
      }
      expect(faceLandmarkerCapabilitiesForPlatform(phone).supportedDelegates, {
        Delegate.cpu,
        Delegate.gpu,
      }, reason: gpu);
    }
    // The table names neither Android target for their GPU anywhere.
    const macos = TaskPlatform(
      operatingSystem: 'macos',
      architecture: 'arm64',
      version: '15.0',
    );
    for (final claim in [
      faceDetectorCapabilitiesForPlatform,
      holisticLandmarkerCapabilitiesForPlatform,
    ]) {
      expect(
        claim(macos).unavailableReasons[Delegate.gpu] ?? '',
        isNot(contains('Android,')),
      );
    }
  });

  test('the iOS Simulator offers the CPU only (UP-031)', () {
    // Google's iOS SDK aborts the app on the simulator's Metal path, so every
    // task that runs GPU on an iPhone offers only the CPU there.
    const device = TaskPlatform(
      operatingSystem: 'ios',
      architecture: 'arm64',
      version: '26.4',
    );
    const simulator = TaskPlatform(
      operatingSystem: 'ios',
      architecture: 'arm64',
      version: '26.4',
      simulator: true,
    );
    final tables = <String, TaskCapabilities Function(TaskPlatform)>{
      'face landmarker': faceLandmarkerCapabilitiesForPlatform,
      'face detector': faceDetectorCapabilitiesForPlatform,
      'hand landmarker': handLandmarkerCapabilitiesForPlatform,
      'pose landmarker': poseLandmarkerCapabilitiesForPlatform,
      'image segmenter': imageSegmenterCapabilitiesForPlatform,
      'object detector': objectDetectorCapabilitiesForPlatform,
    };
    for (final MapEntry(key: task, value: table) in tables.entries) {
      expect(table(device).supportedDelegates, {
        Delegate.cpu,
        Delegate.gpu,
      }, reason: task);
      final capabilities = table(simulator);
      expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: task);
      expect(
        capabilities.unavailableReasons[Delegate.gpu],
        contains('UP-031'),
        reason: task,
      );
    }
  });

  test("an iPhone offers Holistic's CPU only (UP-026)", () {
    // Google's iOS library cannot open Holistic's face blendshapes model on
    // Metal, as on the desktop GPUs; the other landmark tasks keep the GPU.
    const device = TaskPlatform(
      operatingSystem: 'ios',
      architecture: 'arm64',
      version: '27.0',
    );
    final holistic = holisticLandmarkerCapabilitiesForPlatform(device);
    expect(holistic.supportedDelegates, {Delegate.cpu});
    expect(holistic.unavailableReasons[Delegate.gpu], contains('UP-026'));
    expect(poseLandmarkerCapabilitiesForPlatform(device).supportedDelegates, {
      Delegate.cpu,
      Delegate.gpu,
    });
    // The simulator keeps reporting its own, wider gap.
    expect(
      holisticLandmarkerCapabilitiesForPlatform(
        const TaskPlatform(
          operatingSystem: 'ios',
          architecture: 'arm64',
          version: '27.0',
          simulator: true,
        ),
      ).unavailableReasons[Delegate.gpu],
      contains('UP-031'),
    );
  });
}

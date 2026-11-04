/// Where one vision task runs: the registered browser adapter (Google's
/// JavaScript runtime), or Google's native runtime on a worker isolate.
/// Every task class forwards here, on every platform.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import '../types/vision_types.dart';
import '../vision_task_backend.dart';
import 'checks.dart';
import 'live_stream.dart';
import 'native_interface.dart';
import 'native_tasks.dart';
import 'sdk_vision_task.dart';

export 'native_interface.dart';

/// One task on whichever runtime serves it here.
final class VisionTaskRunner<R> {
  VisionTaskRunner._(this._sdk, this._native, this.runningMode);
  final SdkVisionTask<R>? _sdk;
  final NativeTaskRunner<R>? _native;
  Future<void>? _disposal;

  /// The mode the task was created in.
  final RunningMode runningMode;

  VisionTaskChecks get _checks => _sdk?.checks ?? _native!.checks;

  /// The flow limiter of a task created for LIVE_STREAM, which runs on
  /// Google's VIDEO graph.
  late final LiveStreamLimiter<R>? _live = runningMode == RunningMode.liveStream
      ? LiveStreamLimiter(_checks, _liveFrame)
      : null;

  /// Runs a frame the limiter started, making a deferred frame's pixels
  /// now. Asynchronous, so a backend or producer that fails at once still
  /// reports through the limiter rather than out of a submission it already
  /// accepted.
  Future<R> _liveFrame(LiveFrame frame) async {
    final (image, rotationDegrees, timestampMilliseconds, region) = frame;
    final started = isDeferredImage(image)
        ? (
            await producedImage(image),
            rotationDegrees,
            timestampMilliseconds,
            region,
          )
        : frame;
    return _sdk?.liveFrame(started) ?? _native!.processLiveFrame(started);
  }

  /// Resolves the model, then opens the task: through [backend] where the
  /// web plugin registered one (browsers), else on Google's
  /// native runtime after [capabilities] admits the delegate and [validate]
  /// passes, with [native] creating the task on a worker. [name] appears in
  /// errors.
  static Future<VisionTaskRunner<R>> open<R, O extends VisionTaskOptions>(
    O options, {
    required String name,
    required VisionBackendFactory<R, O>? backend,
    required NativeVisionTask<R> Function(O) native,
    Future<TaskCapabilities> Function()? capabilities,
    void Function()? validate,
  }) async {
    await resolveTaskModel(options);
    if (backend != null) {
      return VisionTaskRunner._(
        SdkVisionTask(await backend(options), options.runningMode, name: name),
        null,
        options.runningMode,
      );
    }
    if (capabilities != null) {
      requireDelegate(await capabilities(), options.delegate);
    }
    validate?.call();
    return VisionTaskRunner._(
      null,
      await openNativeTask(options, native, name),
      options.runningMode,
    );
  }

  /// The browser overlay behind this task, when its backend draws.
  VisionTaskOverlayBackend? get overlayBackend => _sdk?.overlayBackend;

  /// IMAGE inference; [regionOfInterest] only for the tasks that accept one.
  Future<R> image(
    VisionImage image,
    int rotationDegrees, {
    VisionRegionOfInterest? regionOfInterest,
  }) async {
    refuseDeferredImage(image);
    return _sdk?.image(
          image,
          rotationDegrees: rotationDegrees,
          regionOfInterest: regionOfInterest,
        ) ??
        _native!.processImage(image, rotationDegrees, regionOfInterest);
  }

  /// VIDEO inference with a strictly increasing millisecond timestamp.
  Future<R> video(
    VisionImage image,
    int rotationDegrees,
    int timestampMilliseconds, {
    VisionRegionOfInterest? regionOfInterest,
  }) async {
    refuseDeferredImage(image);
    return _sdk?.video(
          image,
          timestampMilliseconds: timestampMilliseconds,
          rotationDegrees: rotationDegrees,
          regionOfInterest: regionOfInterest,
        ) ??
        _native!.processVideo(
          image,
          rotationDegrees,
          timestampMilliseconds,
          regionOfInterest,
        );
  }

  /// LIVE_STREAM submission: checks the frame and reserves its timestamp,
  /// then runs it, queues it or drops it; its result arrives on [results].
  void liveStream(
    VisionImage image,
    int rotationDegrees,
    int timestampMilliseconds, {
    VisionRegionOfInterest? regionOfInterest,
  }) => _liveStream.submit((
    image,
    rotationDegrees,
    timestampMilliseconds,
    regionOfInterest,
  ));

  /// The live stream's results; any other mode has none.
  Stream<R> get results => _liveStream.results;

  /// Live stream frames accepted but never run; 0 in the other modes.
  int get droppedFrames => _live?.droppedFrames ?? 0;

  LiveStreamLimiter<R> get _liveStream {
    final live = _live;
    if (live == null) _checks.requireMode(RunningMode.liveStream);
    return live!;
  }

  /// Stops accepting requests, runs the live stream's frame in flight and its
  /// queued frame, then drains queued requests and releases the task exactly
  /// once.
  Future<void> dispose() => _disposal ??= () async {
    _checks.markDisposing();
    await _live?.close();
    await (_sdk?.dispose() ?? _native!.dispose());
  }();
}

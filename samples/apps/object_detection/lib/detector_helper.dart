import 'dart:async';

import 'package:mediapipe_vision/mediapipe_vision.dart';

/// The options the settings sheet changes, with the defaults of Google's
/// Android sample.
class DetectorSettings {
  const DetectorSettings({
    this.threshold = 0.5,
    this.maxResults = 3,
    this.delegate = Delegate.cpu,
  });

  /// Detections scoring below this are dropped.
  final double threshold;

  /// The most detections a frame returns.
  final int maxResults;

  /// The processor the detector runs on.
  final Delegate delegate;

  DetectorSettings copyWith({
    double? threshold,
    int? maxResults,
    Delegate? delegate,
  }) => DetectorSettings(
    threshold: threshold ?? this.threshold,
    maxResults: maxResults ?? this.maxResults,
    delegate: delegate ?? this.delegate,
  );

  @override
  bool operator ==(Object other) =>
      other is DetectorSettings &&
      other.threshold == threshold &&
      other.maxResults == maxResults &&
      other.delegate == delegate;

  @override
  int get hashCode => Object.hash(threshold, maxResults, delegate);
}

/// A result and how long it took, as the sample shows them.
typedef ResultBundle = ({
  ObjectDetectorResult result,
  int inferenceMilliseconds,
});

/// Creates, runs and closes an [ObjectDetector] for one running mode.
///
/// The Flutter counterpart of `ObjectDetectorHelper.kt` in Google's Android
/// sample: [setupObjectDetector] builds the detector from [settings],
/// [detectImage], [detectVideoFrame] and [detectLivestreamFrame] run it, and
/// [clearObjectDetector] closes it. A GPU the platform refuses is reported
/// through [onError] and the helper carries on with the CPU, as Google's
/// sample does.
class ObjectDetectorHelper {
  ObjectDetectorHelper({
    required this.runningMode,
    required this.settings,
    this.onError,
  });

  final RunningMode runningMode;

  /// The options the next [setupObjectDetector] uses.
  DetectorSettings settings;

  /// Called with a message when the detector fails, or when the GPU is
  /// unavailable and the helper switched [settings] to the CPU.
  final void Function(String message, {bool gpuError})? onError;

  ObjectDetector? _detector;
  StreamSubscription<ObjectDetectorResult>? _subscription;
  final _liveResults = StreamController<ResultBundle>.broadcast();
  final _clock = Stopwatch()..start();
  int _lastTimestamp = -1;

  /// Whether a detector is open and ready for frames.
  bool get isReady => _detector != null;

  /// Live stream results, each with the time from capture to result.
  Stream<ResultBundle> get liveResults => _liveResults.stream;

  /// Closes any open detector and opens one with [settings]. Calls made
  /// while one is opening run after it, in order.
  Future<void> setupObjectDetector() =>
      _setup = _setup.catchError((_) {}).then((_) => _open());
  Future<void> _setup = Future.value();

  Future<void> _open() async {
    await clearObjectDetector();
    final capabilities = await queryObjectDetectorCapabilities();
    var delegate = settings.delegate;
    if (!capabilities.supportedDelegates.contains(delegate)) {
      delegate = _fallBackToCpu(capabilities.unavailableReasons[delegate]);
    }
    ObjectDetector detector;
    try {
      detector = await _create(delegate);
    } on TaskException catch (error) {
      if (!error.gpuUnavailable) rethrow;
      detector = await _create(_fallBackToCpu(error.message));
    }
    if (runningMode == RunningMode.liveStream) {
      // Listen before the first frame; the stream ends after a failure.
      _subscription = detector.results.listen(
        (result) => _liveResults.add((
          result: result,
          inferenceMilliseconds:
              _clock.elapsedMilliseconds -
              (result.timestampMilliseconds ?? _clock.elapsedMilliseconds),
        )),
        onError: (Object error) => onError?.call('$error'),
      );
    }
    _detector = detector;
  }

  Future<ObjectDetector> _create(Delegate delegate) => ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      runningMode: runningMode,
      delegate: delegate,
      scoreThreshold: settings.threshold,
      maxResults: settings.maxResults,
    ),
  );

  Delegate _fallBackToCpu(String? reason) {
    settings = settings.copyWith(delegate: Delegate.cpu);
    onError?.call(
      'GPU is unavailable here${reason == null ? '' : ': $reason'}. '
      'Using the CPU.',
      gpuError: true,
    );
    return Delegate.cpu;
  }

  /// Detects objects in a still image. Requires [RunningMode.image].
  Future<ResultBundle> detectImage(VisionImage image) async {
    final clock = Stopwatch()..start();
    final result = await _require().detect(image);
    return (result: result, inferenceMilliseconds: clock.elapsedMilliseconds);
  }

  /// Detects objects in one decoded video frame. Requires [RunningMode.video]
  /// and strictly increasing timestamps.
  Future<ResultBundle> detectVideoFrame(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
  }) async {
    final clock = Stopwatch()..start();
    final result = await _require().detectForVideo(
      image,
      timestampMilliseconds: timestampMilliseconds,
      rotationDegrees: rotationDegrees,
    );
    return (result: result, inferenceMilliseconds: clock.elapsedMilliseconds);
  }

  /// Submits a camera frame and returns its timestamp; the result arrives on
  /// [liveResults]. Requires [RunningMode.liveStream]. The detector runs one
  /// frame at a time and drops the frames that arrive meanwhile.
  int detectLivestreamFrame(VisionImage image, {int rotationDegrees = 0}) {
    final detector = _require();
    // Timestamps must strictly increase, even for frames a millisecond apart.
    final timestamp = _clock.elapsedMilliseconds > _lastTimestamp
        ? _clock.elapsedMilliseconds
        : _lastTimestamp + 1;
    _lastTimestamp = timestamp;
    detector.detectAsync(
      image,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    );
    return timestamp;
  }

  ObjectDetector _require() =>
      _detector ?? (throw StateError('Call setupObjectDetector first.'));

  /// Closes the detector. [setupObjectDetector] can open it again.
  Future<void> clearObjectDetector() async {
    // Taken first, so a setup that starts meanwhile keeps its own detector.
    final detector = _detector;
    final subscription = _subscription;
    _detector = null;
    _subscription = null;
    await detector?.dispose();
    await subscription?.cancel();
  }

  /// Closes the detector and the [liveResults] stream for good.
  Future<void> close() async {
    await clearObjectDetector();
    await _liveResults.close();
  }
}

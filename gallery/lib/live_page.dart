import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'catalog.dart';
import 'gallery_assets_io.dart'
    if (dart.library.js_interop) 'web/gallery_assets.dart';
import 'live/live_camera_controller.dart';
import 'live/camera_geometry.dart';
import 'live/live_camera_view.dart';
import 'live/live_registry.dart';
import 'live/mask_overlay.dart';
import 'live/overlay_visibility.dart';
import 'live/speed_history.dart';
import 'live/still_image.dart';
import 'live/task_models.dart';
import 'live/video_file_controller.dart';
import 'live/task_settings.dart';
import 'live/live_output.dart';
import 'live/task_settings_panel.dart';
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/speed_chart.dart';
import 'ui/workspace.dart';

/// The bundled clip the video file mode opens with (samples/README.md).
const sampleClip = 'scene.mp4';

/// One live camera demo, whichever task the tile names.
///
/// Camera capture and timing live in [LiveCameraController], a video file's
/// frames in [VideoFileController]. This page shares model settings, delegate
/// selection and overlays between the camera, a still image and a video file
/// for every vision demo in the live registry.
class LivePage extends StatefulWidget {
  const LivePage({
    super.key,
    required this.task,
    required this.platform,
    this.navigationOpen,
    this.initialStillImage = false,
    this.stillImagePicker,
    this.onOpenMenu,
  });

  final GalleryTask task;
  final TaskPlatform platform;
  final ValueListenable<bool>? navigationOpen;
  final bool initialStillImage;
  final Future<XFile?> Function()? stillImagePicker;
  final VoidCallback? onOpenMenu;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage>
    with WidgetsBindingObserver, RevisionedState, ModelSelectionState {
  late final LiveDemo _demo = liveDemoFor(widget.task.id)!;
  late final LiveTask<Object?> _task = _demo.task();
  late final LiveCameraController<Object?> _controller =
      LiveCameraController<Object?>(_task);
  late final VideoFileController _video = VideoFileController(_task);
  late final List<TaskSetting> _settings =
      taskSettings[widget.task.runtimeId] ?? const [];
  late final List<TaskModel> _models =
      taskModels[widget.task.runtimeId] ?? const [];

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _refreshMask();
  }

  @override
  bool get bumpsRevision => !_frameRebuild;

  /// Set while a camera frame rebuilds the page. The settings panel shows
  /// nothing a frame changes, so it and an open sheet are left alone.
  bool _frameRebuild = false;

  /// What the panel shows of the controller: whether a restart is under way,
  /// the delegate and a segmenter's labels.
  (bool, Delegate, int)? _panelState;

  /// Whether the phone's settings sheet is open over the feed.
  bool _settingsOpen = false;

  /// Image Segmenter draws its mask as Google's demo does, with a legend,
  /// rather than with the connections other tasks draw.
  bool get _segmenter => widget.task.runtimeId == 'image_segmenter';
  final _masks = SegmentationMaskImages();

  /// The result on screen: the still image's, the video file's current
  /// frame's, or the camera's newest.
  Object? get _shownResult => switch (_mode) {
    _VisionInputMode.image => _imageResult,
    _VisionInputMode.video => _video.result,
    _VisionInputMode.camera => _controller.result,
  };

  List<String> get _labels => switch (_shownResult) {
    ImageSegmenterResult(:final labels) => labels,
    _ => const [],
  };

  bool get _confidenceMasks =>
      _segmenter && _task.settings.choice('outputConfidenceMasks') == 1;

  /// Builds the mask image for the result on screen in the chosen style.
  void _refreshMask() {
    if (!_segmenter) return;
    _masks.show(
      _shownResult is ImageSegmenterResult
          ? _shownResult! as ImageSegmenterResult
          : null,
      (
        confidence: _confidenceMasks,
        selectedClass: _task.settings.choice('confidenceClass'),
      ),
    );
  }

  CustomPainter _overlay(Object? result, PreviewTransform transform) =>
      _segmenter
      ? MaskOverlay(
          _masks,
          transform: transform,
          opacity: _task.settings.share('opacity'),
        )
      : _demo.overlay(result, transform, _showConnections, _showPoints);

  /// Google's color legend under the view, while classes are colored.
  List<Widget> _legend() => [
    if (_segmenter && !_confidenceMasks && _labels.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SegmenterLegend(_labels),
      ),
  ];

  late final List<Delegate> _delegates =
      widget.task.capabilities(widget.platform).supportedDelegates.toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  String? _error;
  bool _autoStarted = false;

  /// Each frame's inference time since the page opened, for the Stats chart.
  final _speed = SpeedHistory();
  final _speedClock = Stopwatch()..start();
  int _speedFrames = 0;
  bool _showStats = false;

  /// Bumped after every build. On phones Output and Stats open as dialogs,
  /// routes of their own, and follow the page through this.
  final _dialogRevision = ValueNotifier(0);

  /// Overlays draw connections and boxes without individual points.
  bool get _showConnections => !debugHideOverlay;
  static const _showPoints = false;
  late _VisionInputMode _mode = widget.initialStillImage && _hasImageMode
      ? _VisionInputMode.image
      : _VisionInputMode.camera;
  Uint8List? _imageBytes;
  VisionImage? _imageInput;
  Size? _imageSize;
  String? _imageName;
  Object? _imageResult;
  Delegate? _imageDelegate;
  double? _imageMilliseconds;
  String? _imageError;
  bool _imageBusy = false;
  int _imageRevision = 0;
  int _modeRevision = 0;
  Future<void> _imageOperations = Future.value();
  Future<void> _cameraStopped = Future.value();

  bool get _hasImageMode => widget.task.live;

  @override
  void initState() {
    super.initState();
    _controller.delegate = preferredDelegate(_delegates);
    _controller.addListener(_onControllerChanged);
    _video.addListener(_onVideoChanged);
    widget.navigationOpen?.addListener(_onCoverChanged);
    _onCoverChanged();
    WidgetsBinding.instance.addObserver(this);
    if (_mode == _VisionInputMode.camera) _findCameras();
  }

  /// Whether Android sent the app to the background with the camera running,
  /// so that it starts again when the app returns.
  bool _stoppedInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On Android a camera frame that reaches Flutter after the activity is
    // destroyed crashes the app ("FlutterJNI is not attached to native"), as
    // backing out of a running demo did on a Pixel 8a. Flutter's camera plugin
    // leaves lifecycle to the app, so the camera stops as soon as the app
    // leaves the foreground. Not while the permission prompt is up: the camera
    // opens last in a start, so it is not running yet then.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (state == AppLifecycleState.inactive && _controller.running) {
      _stoppedInBackground = true;
      unawaited(_controller.stop());
    } else if (state == AppLifecycleState.resumed && _stoppedInBackground) {
      _stoppedInBackground = false;
      unawaited(_start());
    }
  }

  /// The navigation drawer or the settings sheet over the feed pauses it.
  void _onCoverChanged() => _controller.setProcessingPaused(
    (widget.navigationOpen?.value ?? false) || _settingsOpen,
  );

  void _onControllerChanged() {
    final frames = _controller.processedFrames;
    if (frames != _speedFrames) {
      _speedFrames = frames;
      // One notification per processed frame; a restart counts from zero.
      if (frames > 0 && _controller.running) {
        _speed.add(
          _controller.delegate,
          _controller.inferenceMilliseconds,
          _speedClock.elapsed,
          dropped: _controller.droppedFrames,
        );
      }
    }
    if (!mounted) return;
    final panel = (
      _controller.changing,
      _controller.delegate,
      Object.hashAll(_labels),
    );
    _frameRebuild = panel == _panelState;
    _panelState = panel;
    setState(() {});
    _frameRebuild = false;
  }

  void _onVideoChanged() {
    if (!mounted) return;
    // A refused GPU leaves the file on CPU; the delegate control follows.
    if (!_video.loading && _video.delegate != _controller.delegate) {
      _controller.delegate = _video.delegate;
    }
    final panel = (
      _video.loading,
      _controller.delegate,
      Object.hashAll(_labels),
    );
    _frameRebuild = panel == _panelState;
    _panelState = panel;
    setState(() {});
    _frameRebuild = false;
  }

  Future<void> _findCameras() async {
    try {
      await _controller.findCameras();
      if (!mounted) return;
      if (_controller.cameras.isEmpty) {
        setState(
          () => _error = 'No camera found. Connect a webcam and try again.',
        );
        return;
      }
      // Open the demo already running. Guarded so that pressing Stop, or
      // switching delegate, is never undone by a later rebuild.
      if (_mode == _VisionInputMode.camera &&
          _controller.description != null &&
          !_autoStarted) {
        _autoStarted = true;
        unawaited(_start());
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    _imageRevision++;
    _modeRevision++;
    _controller.removeListener(_onControllerChanged);
    _video.removeListener(_onVideoChanged);
    widget.navigationOpen?.removeListener(_onCoverChanged);
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
    _controller.dispose();
    _video.dispose();
    _masks.dispose();
    _dialogRevision.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_mode != _VisionInputMode.camera) return;
    if (_controller.description == null) return;
    try {
      // Start on the current delegate where the task supports it, otherwise
      // on the preferred one.
      await _controller.start(
        delegate: _delegates.contains(_controller.delegate)
            ? _controller.delegate
            : preferredDelegate(_delegates),
        model: widget.task.model,
        warmUpSample: 'assets/samples/${widget.task.sample}',
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  /// Rebuilds a running task with the changed value, as a delegate change
  /// does; a stopped one picks it up when it starts. A display setting only
  /// redraws.
  void _setSetting(String key, Object value) {
    setState(() => _task.settings[key] = value);
    if (_settings.any((setting) => setting.key == key && setting.display)) {
      return;
    }
    _restartCurrentMode();
  }

  void _setDelegate(Delegate delegate) {
    setState(() => _controller.delegate = delegate);
    if (_mode != _VisionInputMode.camera || _controller.running) {
      _restartCurrentMode();
    }
  }

  /// Runs the chosen or uploaded model, or the bundled one again.
  @override
  void modelChanged() {
    final bytes = modelBytes;
    _controller.modelLoader = bytes == null ? null : () async => bytes;
    _restartCurrentMode(startCameraIfStopped: true);
  }

  /// One instance for the page's life: it rebuilds itself on [revision], and
  /// the phone's sheet, which shows it, then has no new widget to rebuild on.
  late final Widget _settingsPanel = _panel();

  Widget _panel() => ListenableBuilder(
    listenable: revision,
    builder: (context, _) => TaskSettingsPanel(
      settings: _settings,
      values: _task.settings,
      delegates: _delegates,
      delegate: _controller.delegate,
      enabled: !_controller.changing,
      onChanged: _setSetting,
      onDelegate: _setDelegate,
      models: _models,
      model: model,
      uploaded: uploaded,
      modelStatus: modelStatus,
      onModel: chooseModel,
      onUpload: uploadModel,
      bundledModel: widget.task.modelFile,
      standardModel: standardModelNames[widget.task.runtimeId] ?? 'Standard',
      labels: _labels,
    ),
  );

  Future<void> _flipCamera() async {
    try {
      await _controller.switchCamera();
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _restartCurrentMode({bool startCameraIfStopped = false}) {
    if (_mode == _VisionInputMode.image) {
      if (_imageInput != null) unawaited(_detectImage());
    } else if (_mode == _VisionInputMode.video) {
      unawaited(_video.restart(delegate: _controller.delegate));
    } else if (_controller.running || startCameraIfStopped) {
      unawaited(_start());
    }
  }

  Future<void> _setMode(_VisionInputMode mode) async {
    if (_mode == mode) return;
    final previous = _mode;
    ++_imageRevision;
    ++_modeRevision;
    setState(() {
      _mode = mode;
      _imageResult = null;
      _imageError = null;
      _imageBusy = false;
    });
    // Each mode opens the shared task in its own running mode, so the mode
    // left behind closes it first.
    if (previous == _VisionInputMode.video) await _video.close();
    if (mode == _VisionInputMode.camera) {
      await _imageOperations;
      if (mounted && _mode == mode) {
        if (_controller.description == null) {
          await _findCameras();
        } else {
          await _start();
        }
      }
      return;
    }
    try {
      _cameraStopped = _controller.stop();
      await _cameraStopped;
      await _imageOperations;
      if (!mounted || _mode != mode) return;
      if (mode == _VisionInputMode.video) {
        await _openVideo();
      } else if (_imageInput != null && !_imageBusy) {
        await _detectImage();
      }
    } on Object catch (error) {
      if (mounted && _mode == mode) setState(() => _imageError = '$error');
    }
  }

  /// The model the page runs: the bundled one, or the one chosen or
  /// uploaded in the settings.
  Future<Uint8List> _currentModel() =>
      (_controller.modelLoader ?? _bundledModelBytes)();

  /// Plays the file already chosen from its start, or the bundled clip.
  Future<void> _openVideo() async {
    final delegate = _delegates.contains(_controller.delegate)
        ? _controller.delegate
        : preferredDelegate(_delegates);
    if (_video.path != null) return _video.restart(delegate: delegate);
    final assets = await GalleryAssets.unpack();
    if (!mounted || _mode != _VisionInputMode.video) return;
    await _video.open(
      assets.path(sampleClip),
      sampleClip,
      delegate: delegate,
      model: _currentModel,
    );
  }

  Future<void> _chooseVideo() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Videos',
            extensions: ['mp4', 'mov', 'm4v', 'webm', 'mkv'],
            mimeTypes: ['video/*'],
            uniformTypeIdentifiers: ['public.movie'],
          ),
        ],
      );
      if (file == null || !mounted || _mode != _VisionInputMode.video) return;
      await _video.open(
        file.path,
        file.name,
        delegate: _controller.delegate,
        model: _currentModel,
      );
    } on Object catch (error) {
      if (mounted) setState(() => _video.error = '$error');
    }
  }

  Future<void> _chooseImage() async {
    final modeRevision = _modeRevision;
    try {
      final file = await (widget.stillImagePicker?.call() ?? pickStillImage());
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final still = await decodeStillImage(bytes);
      if (!mounted ||
          _mode != _VisionInputMode.image ||
          modeRevision != _modeRevision) {
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageInput = still.input;
        _imageSize = still.size;
        _imageName = file.name;
        _imageResult = null;
        _imageError = null;
      });
      unawaited(_detectImage());
    } on Object catch (error) {
      if (mounted &&
          _mode == _VisionInputMode.image &&
          modeRevision == _modeRevision) {
        setState(() => _imageError = '$error');
      }
    }
  }

  Future<void> _detectImage() {
    final input = _imageInput;
    if (input == null) return Future.value();
    final revision = ++_imageRevision;
    var delegate = _controller.delegate;
    final modelLoader = _controller.modelLoader;
    setState(() {
      _imageBusy = true;
      _imageResult = null;
      _imageError = null;
    });
    final operation = _imageOperations.then((_) async {
      var opened = false;
      try {
        await _cameraStopped;
        final model = modelLoader != null
            ? await modelLoader()
            : await _bundledModelBytes();
        if (!mounted ||
            _mode != _VisionInputMode.image ||
            revision != _imageRevision) {
          return;
        }
        try {
          await _task.open(delegate, model, mode: RunningMode.image);
        } on Object {
          // GPU is only the default; a platform that refuses it gets CPU.
          if (delegate != Delegate.gpu) rethrow;
          delegate = Delegate.cpu;
          _controller.delegate = delegate;
          await _task.open(delegate, model, mode: RunningMode.image);
        }
        opened = true;
        if (!mounted ||
            _mode != _VisionInputMode.image ||
            revision != _imageRevision) {
          return;
        }
        final inference = Stopwatch()..start();
        final result = await _task.detectImage(input);
        inference.stop();
        if (mounted &&
            _mode == _VisionInputMode.image &&
            revision == _imageRevision) {
          setState(() {
            _imageResult = result;
            _imageDelegate = delegate;
            _imageMilliseconds = inference.elapsedMicroseconds / 1000;
          });
        }
      } on Object catch (error) {
        if (mounted &&
            _mode == _VisionInputMode.image &&
            revision == _imageRevision) {
          setState(() => _imageError = '$error');
        }
      } finally {
        try {
          if (opened) await _task.close();
        } on Object catch (error) {
          if (mounted &&
              _mode == _VisionInputMode.image &&
              revision == _imageRevision) {
            setState(() => _imageError ??= '$error');
          }
        }
        if (mounted &&
            _mode == _VisionInputMode.image &&
            revision == _imageRevision) {
          setState(() => _imageBusy = false);
        }
      }
    });
    _imageOperations = operation;
    return operation;
  }

  Future<Uint8List> _bundledModelBytes() =>
      GalleryAssets.modelBytes(widget.task.model);

  String _imageSummary(Object result) => switch (result) {
    FaceLandmarkerResult(:final faceLandmarks) =>
      '${faceLandmarks.length} ${faceLandmarks.length == 1 ? 'face' : 'faces'} detected',
    FaceDetectorResult(:final detections) =>
      '${detections.length} ${detections.length == 1 ? 'face' : 'faces'} detected',
    HandLandmarkerResult(:final handLandmarks) =>
      '${handLandmarks.length} ${handLandmarks.length == 1 ? 'hand' : 'hands'} detected',
    GestureRecognizerResult(:final handLandmarks) =>
      '${handLandmarks.length} ${handLandmarks.length == 1 ? 'hand' : 'hands'} recognized',
    PoseLandmarkerResult(:final poseLandmarks) =>
      '${poseLandmarks.length} ${poseLandmarks.length == 1 ? 'pose' : 'poses'} detected',
    HolisticLandmarkerResult(:final poseLandmarks) =>
      poseLandmarks.isEmpty ? 'No pose detected' : 'Body landmarks detected',
    ObjectDetectorResult(:final detections) =>
      '${detections.length} ${detections.length == 1 ? 'object' : 'objects'} detected',
    ImageClassifierResult(:final classifications) =>
      '${classifications.firstOrNull?.categories.length ?? 0} classes returned',
    ImageSegmenterResult(:final categoryMask) =>
      categoryMask == null
          ? 'No category mask returned'
          : 'Segmentation complete',
    _ => 'Analysis complete',
  };

  String get _id => widget.task.runtimeId.replaceAll('_', '-');

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dialogRevision.value++;
    });
    return TaskWorkspace(
      title: widget.task.title,
      onOpenMenu: widget.onOpenMenu,
      settings: _settingsPanel,
      onSettingsSheet: (open) {
        _settingsOpen = open;
        if (mounted) _onCoverChanged();
      },
      children: [
        TaskToolbar(
          task: widget.task,
          leading: _hasImageMode
              ? Segmented<_VisionInputMode>(
                  semanticsIdentifier: '$_id-mode',
                  key: ValueKey('$_id-mode'),
                  segments: [
                    (
                      value: _VisionInputMode.camera,
                      label: 'Camera',
                      icon: LucideIcons.video,
                      key: ValueKey('$_id-mode-camera'),
                    ),
                    (
                      value: _VisionInputMode.image,
                      label: 'Still image',
                      icon: LucideIcons.upload,
                      key: ValueKey('$_id-mode-image'),
                    ),
                    (
                      value: _VisionInputMode.video,
                      label: 'Video file',
                      icon: LucideIcons.film,
                      key: ValueKey('$_id-mode-video'),
                    ),
                  ],
                  selected: _mode,
                  onChanged: (mode) => unawaited(_setMode(mode)),
                )
              : null,
        ),
        if (_mode == _VisionInputMode.image)
          ..._stillImage()
        else if (_mode == _VisionInputMode.video)
          ..._videoFile()
        else
          ..._camera(_controller),
        ..._legend(),
        if (!_phone) ...[const SizedBox(height: 22), _outputCard()],
      ],
    );
  }

  /// Phones keep the screen for the feed: Output and Stats open as dialogs.
  bool get _phone => MediaQuery.sizeOf(context).width < Sizes.compact;

  /// The label size of the Output and Stats buttons on a phone.
  static const _phoneButtonText = 12.0;

  /// Opens a card over the page on a phone, rebuilt as the page changes.
  Future<void> _showDialogCard(Widget Function(VoidCallback close) card) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 48,
          ),
          child: SingleChildScrollView(
            child: ValueListenableBuilder<int>(
              valueListenable: _dialogRevision,
              builder: (context, _, _) =>
                  card(() => Navigator.of(dialogContext).pop()),
            ),
          ),
        ),
      );

  Widget _outputButton() => OutlineButton(
    key: ValueKey('$_id-output-button'),
    icon: LucideIcons.listChecks,
    label: 'Output',
    tooltip: 'Show output',
    fontSize: _phoneButtonText,
    onPressed: () => _showDialogCard((close) => _outputCard(onClose: close)),
  );

  Widget _outputCard({VoidCallback? onClose}) {
    final result = _shownResult;
    final output = liveOutput(result);
    if (output == null) {
      return OutputCard(
        title: 'Results',
        empty: switch (_mode) {
          _VisionInputMode.image =>
            'Choose an image to see what the task finds.',
          _VisionInputMode.video => 'Results appear once the video plays.',
          _VisionInputMode.camera => 'Results appear once the camera runs.',
        },
        onClose: onClose,
      );
    }
    return OutputCard(
      key: ValueKey('$_id-output'),
      title: output.title,
      count: output.count,
      items: output.items,
      empty: output.empty,
      onClose: onClose,
    );
  }

  List<Widget> _stillImage() {
    final bytes = _imageBytes;
    final size = _imageSize;
    if (bytes == null || size == null) {
      return [
        StillCard(
          onChoose: _chooseImage,
          message: _imageError,
          error: _imageError != null,
        ),
      ];
    }
    final result = _imageResult;
    return [
      FeedFrame(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: size.width / size.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes, fit: BoxFit.fill),
                    LayoutBuilder(
                      builder: (context, constraints) => CustomPaint(
                        key: ValueKey('$_id-still-overlay'),
                        painter: _overlay(
                          result,
                          PreviewTransform.fit(
                            frameSize: size,
                            rotationDegrees: 0,
                            viewSize: constraints.biggest,
                            mirror: false,
                          ),
                        ),
                      ),
                    ),
                    if (_imageBusy)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: FeedButton(
                icon: LucideIcons.imageUp,
                tooltip: 'Change image',
                onPressed: _chooseImage,
              ),
            ),
          ],
        ),
      ),
      FeedStatus(
        parts: [
          ?_imageName,
          if (result != null) _imageSummary(result),
          if (result != null && _imageMilliseconds != null)
            'Inference ${_imageMilliseconds!.toStringAsFixed(1)} ms',
        ],
        delegate: result != null && _imageMilliseconds != null
            ? (_imageDelegate == Delegate.gpu ? 'GPU' : 'CPU')
            : null,
        trailing: _phone ? _outputButton() : null,
      ),
      if (_imageError case final error?)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            error,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: Sizes.sm,
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlineButton(
          icon: LucideIcons.upload,
          label: 'Change image',
          tooltip: 'Choose another image',
          onPressed: _chooseImage,
        ),
      ),
    ];
  }

  /// A video file in video mode: every frame runs, in order, and the view
  /// shows each with its result as the task returns it.
  List<Widget> _videoFile() {
    final video = _video;
    final picture = video.picture;
    final size = video.frameSize;
    final turns = video.rotationDegrees ~/ 90;
    final error = video.error;
    return [
      FeedFrame(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (picture != null && size != null)
              Center(
                child: AspectRatio(
                  aspectRatio: turns.isOdd
                      ? size.height / size.width
                      : size.width / size.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RotatedBox(
                        quarterTurns: turns,
                        child: RawImage(image: picture, fit: BoxFit.fill),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) => CustomPaint(
                          key: ValueKey('$_id-video-overlay'),
                          painter: _overlay(
                            video.result,
                            PreviewTransform.fit(
                              frameSize: size,
                              rotationDegrees: video.rotationDegrees,
                              viewSize: constraints.biggest,
                              mirror: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (video.loading)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              left: 14,
              bottom: 14,
              child: Row(
                children: [
                  FeedButton(
                    icon: video.playing ? LucideIcons.pause : LucideIcons.play,
                    tooltip: video.playing ? 'Pause' : 'Play',
                    onPressed: video.loading || video.done
                        ? null
                        : video.playing
                        ? video.pause
                        : video.play,
                  ),
                  const SizedBox(width: 8),
                  FeedButton(
                    icon: LucideIcons.rotateCcw,
                    tooltip: 'Restart',
                    onPressed: video.loading || video.path == null
                        ? null
                        : () => unawaited(
                            video.restart(delegate: _controller.delegate),
                          ),
                  ),
                  const SizedBox(width: 8),
                  FeedButton(
                    icon: LucideIcons.fileVideo,
                    tooltip: 'Choose video file',
                    onPressed: _chooseVideo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      FeedStatus(
        parts: [
          ?video.name,
          if (video.done)
            '${video.frames} ${video.frames == 1 ? 'frame' : 'frames'} done'
          else if (video.frames > 0)
            switch (video.expectedFrames) {
              final expected? => 'Frame ${video.frames} of ~$expected',
              null => 'Frame ${video.frames}',
            },
          if (video.frames > 0)
            '${video.averageFrameMilliseconds.toStringAsFixed(1)} ms per frame',
          if (video.duplicates > 0)
            '${video.duplicates} repeated '
                '${video.duplicates == 1 ? 'timestamp' : 'timestamps'} skipped',
          if (!video.resultsMatchFrames) 'Results out of step with frames',
        ],
        delegate: video.frames > 0
            ? (video.delegate == Delegate.gpu ? 'GPU' : 'CPU')
            : null,
        trailing: _phone ? _outputButton() : null,
      ),
      for (final message in [?video.notice, ?error])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: Sizes.sm,
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlineButton(
          icon: LucideIcons.fileVideo,
          label: 'Choose video file',
          tooltip: 'Run another video file',
          onPressed: _chooseVideo,
        ),
      ),
    ];
  }

  List<Widget> _camera(LiveCameraController<Object?> controller) {
    final error = _error ?? controller.error;
    final phone = _phone;
    final stats = OutlineButton(
      key: ValueKey('$_id-stats'),
      icon: LucideIcons.chartLine,
      label: 'Stats',
      tooltip: phone || !_showStats ? 'Show stats' : 'Hide stats',
      // On a phone Stats matches Output beside it.
      bordered: phone || _showStats,
      fontSize: phone ? _phoneButtonText : Sizes.md,
      onPressed: phone
          ? () => _showDialogCard((close) => _statsCard(onClose: close))
          : () => setState(() => _showStats = !_showStats),
    );
    return [
      FeedFrame(
        // A phone shows the camera at its own upright shape, as tall as the
        // screen allows, rather than a wide frame with bars beside it.
        aspectRatio: phone ? controller.previewAspect ?? 3 / 4 : 16 / 9,
        maxHeight: phone ? MediaQuery.sizeOf(context).height * .62 : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LiveCameraView(
              controller: controller,
              showConnections: _showConnections,
              showPoints: _showPoints,
              painter: (transform) => _overlay(controller.result, transform),
              placeholder: switch (error) {
                final String error => Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFF0F3F2)),
                ),
                null => const CircularProgressIndicator(),
              },
            ),
            if (controller.initializing &&
                controller.frameSize != null &&
                error == null)
              Center(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xDD101715),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Model initializing...',
                            style: TextStyle(color: Color(0xFFF0F3F2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (controller.canSwitchCamera)
              Positioned(
                left: 14,
                bottom: 14,
                child: FeedButton(
                  icon: LucideIcons.switchCamera,
                  tooltip: controller.isFrontCamera
                      ? 'Switch to back camera'
                      : 'Switch to front camera',
                  onPressed: controller.changing ? null : _flipCamera,
                ),
              ),
          ],
        ),
      ),
      FeedStatus(
        parts: controller.running
            ? [
                '${controller.recentFramesPerSecond.toStringAsFixed(1)} fps',
                '${controller.recentInferenceMilliseconds.toStringAsFixed(0)} ms',
              ]
            : [controller.initializing ? 'Model initializing...' : 'Stopped'],
        delegate: controller.delegate == Delegate.gpu ? 'GPU' : 'CPU',
        trailing: phone
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [_outputButton(), const SizedBox(width: 8), stats],
              )
            : stats,
      ),
      if (controller.notice case final notice?)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            notice,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: Sizes.xs,
            ),
          ),
        ),
      if (_showStats && !phone) ...[const SizedBox(height: 10), _statsCard()],
    ];
  }

  /// Stats switches the task's delegate as the settings do, so its other
  /// line can join the chart, and clears the chart.
  Widget _statsCard({VoidCallback? onClose}) => StatsCard(
    key: ValueKey('$_id-stats-card'),
    history: _speed,
    delegates: _delegates,
    delegate: _controller.delegate,
    onSwitchDelegate: _controller.changing ? null : _setDelegate,
    onReset: () => setState(_speed.clear),
    onClose: onClose,
  );
}

enum _VisionInputMode { camera, image, video }

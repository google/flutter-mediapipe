import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:video_frames/video_frames.dart';

import 'detector_helper.dart';
import 'media/still_image.dart';
import 'media/video_frame.dart';
import 'overlay.dart';

/// The Gallery tab: detection on a chosen photo in image mode, or on every
/// frame of a chosen video in video mode.
class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    required this.settings,
    required this.inferenceMilliseconds,
    required this.onError,
  });

  final ValueNotifier<DetectorSettings> settings;
  final ValueNotifier<int?> inferenceMilliseconds;
  final void Function(String message) onError;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  /// Bumped to stop the video loop, or a detection whose result is stale.
  int _generation = 0;
  ObjectDetectorHelper? _helper;

  XFile? _file;
  ui.Image? _picture;
  int _rotationDegrees = 0;
  ObjectDetectorResult? _result;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    final helper = _helper;
    if (helper == null || helper.settings == widget.settings.value) return;
    // Run the same photo, or the video from its start, with the new options.
    if (_file case final file?) unawaited(_open(file));
  }

  void _onDetectorError(String message, {bool gpuError = false}) {
    if (gpuError) widget.settings.value = _helper!.settings;
    widget.onError(message);
  }

  Future<void> _pick() async {
    try {
      // One picker for both, as Google's sample has. Without full metadata
      // iOS shows its picker without asking for photo library access.
      final file = await ImagePicker().pickMedia(requestFullMetadata: false);
      if (file != null) await _open(file);
    } on Object catch (error) {
      widget.onError('$error');
    }
  }

  Future<void> _open(XFile file) async {
    final generation = ++_generation;
    final isVideo = _looksLikeVideo(file);
    await _helper?.close();
    final helper = _helper = ObjectDetectorHelper(
      runningMode: isVideo ? RunningMode.video : RunningMode.image,
      settings: widget.settings.value,
      onError: _onDetectorError,
    );
    if (!mounted || generation != _generation) return;
    // A new file shows a spinner until its first frame; a rerun with new
    // settings keeps the old picture until then.
    if (file != _file) _drop();
    setState(() {
      _file = file;
      _result = null;
    });
    try {
      await helper.setupObjectDetector();
      if (isVideo) {
        await _runVideo(file.path, helper, generation);
      } else {
        await _runImage(file, helper, generation);
      }
    } on Object catch (error) {
      if (mounted && generation == _generation) widget.onError('$error');
    }
  }

  Future<void> _runImage(
    XFile file,
    ObjectDetectorHelper helper,
    int generation,
  ) async {
    final still = await decodeStillImage(await file.readAsBytes());
    if (!mounted || generation != _generation) {
      still.picture.dispose();
      return;
    }
    _show(still.picture, 0);
    final bundle = await helper.detectImage(still.input);
    if (!mounted || generation != _generation) return;
    widget.inferenceMilliseconds.value = bundle.inferenceMilliseconds;
    setState(() => _result = bundle.result);
  }

  /// Decodes [path] frame by frame and detects objects in each frame,
  /// playing no faster than the file's own timing.
  Future<void> _runVideo(
    String path,
    ObjectDetectorHelper helper,
    int generation,
  ) async {
    final reader = await VideoFileReader.open(path);
    try {
      final clock = Stopwatch()..start();
      int? last;
      while (mounted && generation == _generation) {
        final frame = await reader.next();
        if (frame == null) break;
        final timestamp = (frame.timestampMicroseconds / 1000).round();
        // Video mode needs strictly increasing timestamps.
        if (!mounted ||
            generation != _generation ||
            (last != null && timestamp <= last)) {
          discardFrame(frame);
          continue;
        }
        last = timestamp;
        final wait = timestamp - clock.elapsedMilliseconds;
        if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
        final prepared = await prepareFrame(frame);
        final bundle = await helper.detectVideoFrame(
          prepared.input,
          timestampMilliseconds: timestamp,
          rotationDegrees: reader.rotationDegrees,
        );
        if (!mounted || generation != _generation) {
          prepared.picture.dispose();
          break;
        }
        widget.inferenceMilliseconds.value = bundle.inferenceMilliseconds;
        _show(prepared.picture, reader.rotationDegrees, bundle.result);
      }
    } finally {
      await reader.close();
    }
  }

  void _show(
    ui.Image picture,
    int rotationDegrees, [
    ObjectDetectorResult? result,
  ]) {
    final previous = _picture;
    setState(() {
      _picture = picture;
      _rotationDegrees = rotationDegrees;
      _result = result;
    });
    // Dispose after the frame that stops drawing it.
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  void _drop() {
    final previous = _picture;
    _picture = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  static bool _looksLikeVideo(XFile file) {
    if (file.mimeType case final mime?) return mime.startsWith('video/');
    final name = file.name.toLowerCase();
    return const [
      '.mp4',
      '.mov',
      '.m4v',
      '.webm',
      '.mkv',
      '.avi',
      '.3gp',
    ].any(name.endsWith);
  }

  @override
  void dispose() {
    _generation++;
    widget.settings.removeListener(_onSettingsChanged);
    unawaited(_helper?.close());
    _picture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = _picture;
    return Scaffold(
      body: picture == null && _file != null
          ? const Center(child: CircularProgressIndicator())
          : picture == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Choose a photo or a video to detect objects in.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: DetectionView(
                frameSize: Size(
                  picture.width.toDouble(),
                  picture.height.toDouble(),
                ),
                rotationDegrees: _rotationDegrees,
                result: _result,
                child: RotatedBox(
                  quarterTurns: _rotationDegrees ~/ 90,
                  child: RawImage(image: picture, fit: BoxFit.fill),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Choose a photo or video',
        onPressed: _pick,
        child: const Icon(Icons.add),
      ),
    );
  }
}

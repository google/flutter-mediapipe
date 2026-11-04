import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:video_frames/video_frames.dart';

import 'live_task.dart';
import 'operation_queue.dart';
import 'video_frame_image.dart';

/// Runs a video file through one task in video mode: every frame, in order,
/// with the file's own timestamps, so tracking follows the whole file. The
/// camera runs in live stream mode instead, where frames the task has no time
/// for are dropped.
///
/// Play, pause and restart only: video mode's timestamps cannot go back, so
/// starting over means a new task.
class VideoFileController extends ChangeNotifier {
  VideoFileController(this.task);

  /// The task being demonstrated, shared with the page's other modes, which
  /// close it before this opens it.
  final LiveTask<Object?> task;

  /// The file playing, and the name the status line shows for it.
  String? path;
  String? name;

  /// The processor the task runs on; a refused GPU falls back to CPU.
  Delegate delegate = Delegate.cpu;
  Future<Uint8List> Function()? _model;

  VideoFileReader? _reader;
  bool _opened = false;
  bool _looping = false;
  bool _disposed = false;
  int _generation = 0;
  final _operations = OperationQueue();
  Future<void>? _loop;

  /// Opening the file and the task.
  bool loading = false;

  /// Decoding and running frames; false while paused, stopped or done.
  bool playing = false;

  /// The file's last frame has run.
  bool done = false;
  String? error;

  /// Set when the task refused the GPU and the file runs on CPU.
  String? notice;

  /// The frame on screen, its size before rotation, and the clockwise turn
  /// that stands it upright, from the file's metadata.
  ui.Image? picture;
  ui.Size? frameSize;
  int rotationDegrees = 0;

  /// The result for [picture].
  Object? result;

  /// Frames run so far, each answered with a result for its own timestamp.
  int frames = 0;

  /// Frames skipped because their timestamp, in whole milliseconds, repeated
  /// the one before; video mode needs strictly increasing timestamps.
  int duplicates = 0;

  /// The last frame's timestamp, in milliseconds.
  int? lastTimestamp;

  /// Whether every result so far carried its frame's timestamp.
  bool resultsMatchFrames = true;

  /// How many frames the file declares: its duration times its frame rate.
  int? expectedFrames;

  double _totalFrameMilliseconds = 0;

  /// Mean time per frame: conversion for the task and the view, then
  /// inference.
  double get averageFrameMilliseconds =>
      frames == 0 ? 0 : _totalFrameMilliseconds / frames;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Opens [path], named [name] on the status line, and plays it from the
  /// start on [delegate] with the model [model] supplies.
  Future<void> open(
    String path,
    String name, {
    required Delegate delegate,
    required Future<Uint8List> Function() model,
  }) {
    this.path = path;
    this.name = name;
    this.delegate = delegate;
    _model = model;
    return restart();
  }

  /// Opens the file and a new task again and plays from the first frame.
  Future<void> restart({Delegate? delegate}) {
    if (path == null || _model == null) return Future.value();
    final generation = ++_generation;
    final chosen = delegate ?? this.delegate;
    if (chosen == Delegate.gpu) notice = null;
    playing = false;
    loading = true;
    done = false;
    error = null;
    _reset();
    _changed();
    return _operations.add(() async {
      await _release();
      if (generation != _generation) return;
      try {
        final model = await _model!();
        try {
          await task.open(chosen, model, mode: RunningMode.video);
          this.delegate = chosen;
        } on TaskException catch (refused) {
          // GPU is only the default; a platform that refuses it gets CPU,
          // visibly, as the camera does.
          if (chosen != Delegate.gpu || !refused.gpuUnavailable) rethrow;
          notice = 'GPU unavailable, using CPU. ${refused.message}';
          await task.open(Delegate.cpu, model, mode: RunningMode.video);
          this.delegate = Delegate.cpu;
        }
        _opened = true;
        if (generation != _generation) return await _release();
        final reader = _reader = await VideoFileReader.open(path!);
        rotationDegrees = reader.rotationDegrees;
        if ((reader.duration, reader.frameRate) case (
          final duration?,
          final rate?,
        )) {
          expectedFrames = (duration.inMicroseconds * rate / 1e6).round();
        }
        if (generation != _generation) return await _release();
        loading = false;
        playing = true;
        _changed();
        _start(generation);
      } catch (failure) {
        if (generation == _generation) {
          error = '$failure';
          loading = false;
          _changed();
        }
        await _release();
      }
    });
  }

  void _reset() {
    picture?.dispose();
    picture = null;
    frameSize = null;
    result = null;
    frames = 0;
    duplicates = 0;
    lastTimestamp = null;
    resultsMatchFrames = true;
    expectedFrames = null;
    _totalFrameMilliseconds = 0;
  }

  /// Stops after the frame in progress.
  void pause() {
    if (!playing) return;
    playing = false;
    _changed();
  }

  /// Continues from the next frame.
  void play() {
    if (playing || done || loading || _reader == null) return;
    playing = true;
    _changed();
    _start(_generation);
  }

  void _start(int generation) {
    if (!_looping) _loop = _run(generation);
  }

  Future<void> _run(int generation) async {
    _looping = true;
    try {
      while (playing && generation == _generation) {
        final reader = _reader!;
        final frame = await reader.next();
        if (generation != _generation) {
          if (frame != null) discardFrame(frame);
          return;
        }
        if (frame == null) {
          done = true;
          playing = false;
          _changed();
          return;
        }
        final timestamp = (frame.timestampMicroseconds / 1000).round();
        if (lastTimestamp case final last? when timestamp <= last) {
          duplicates++;
          discardFrame(frame);
          continue;
        }
        lastTimestamp = timestamp;
        final clock = Stopwatch()..start();
        final prepared = await prepareFrame(frame);
        final detection = await task.detectFrame(
          prepared.input,
          timestamp,
          rotationDegrees: reader.rotationDegrees,
        );
        clock.stop();
        if (generation != _generation) {
          prepared.picture.dispose();
          return;
        }
        picture?.dispose();
        picture = prepared.picture;
        frameSize = ui.Size(frame.width.toDouble(), frame.height.toDouble());
        result = detection;
        if (_timestampOf(detection) != timestamp) resultsMatchFrames = false;
        frames++;
        _totalFrameMilliseconds += clock.elapsedMicroseconds / 1000;
        _changed();
      }
    } catch (failure) {
      if (generation == _generation) {
        error = '$failure';
        playing = false;
        _changed();
      }
    } finally {
      _looping = false;
    }
  }

  /// Stops and releases the file and the task once the frame in progress
  /// ends; the page's other modes take the task over afterwards.
  Future<void> close() {
    _generation++;
    playing = false;
    loading = false;
    return _operations.add(_release);
  }

  Future<void> _release() async {
    await _loop;
    _loop = null;
    final reader = _reader;
    _reader = null;
    await reader?.close();
    if (_opened) {
      _opened = false;
      await task.close();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close().whenComplete(() => picture?.dispose()));
    super.dispose();
  }
}

/// The timestamp a video mode result carries.
int? _timestampOf(Object? result) => switch (result) {
  FaceDetectorResult(:final timestampMilliseconds) => timestampMilliseconds,
  FaceLandmarkerResult(:final timestampMilliseconds) => timestampMilliseconds,
  HandLandmarkerResult(:final timestampMilliseconds) => timestampMilliseconds,
  GestureRecognizerResult(:final timestampMilliseconds) =>
    timestampMilliseconds,
  PoseLandmarkerResult(:final timestampMilliseconds) => timestampMilliseconds,
  HolisticLandmarkerResult(:final timestampMilliseconds) =>
    timestampMilliseconds,
  ObjectDetectorResult(:final timestampMilliseconds) => timestampMilliseconds,
  ImageClassifierResult(:final timestampMilliseconds) => timestampMilliseconds,
  ImageEmbedderResult(:final timestampMilliseconds) => timestampMilliseconds,
  ImageSegmenterResult(:final timestampMilliseconds) => timestampMilliseconds,
  _ => null,
};

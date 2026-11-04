import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../video_frames.dart';
import 'frame_rate.dart';

extension type _VideoCallbacks(JSObject object) implements JSObject {
  external int requestVideoFrameCallback(JSFunction callback);
}

extension type _FrameMetadata(JSObject object) implements JSObject {
  external double get mediaTime;
  external int get presentedFrames;
}

/// Frame rate assumed when the browser cannot report presented frames.
const _fallbackFrameSeconds = 1 / 30;

/// Opens [url] in a hidden `<video>` element. Browsers expose no decoder for
/// a file's frames, only the one the element shows, so the reader seeks to
/// each frame in turn and copies what is on screen.
Future<VideoFileReader> open(String url) async {
  // Seeking a file served over HTTP needs a server that answers range
  // requests; one that does not (Python's http.server, which the tests use)
  // leaves the element seekable only at 0, and every frame would be the
  // first. A blob is seekable wherever it came from; a picked file already is
  // one.
  String? ownUrl;
  if (!url.startsWith('blob:') && !url.startsWith('data:')) {
    final response = await web.window.fetch(url.toJS).toDart;
    if (!response.ok) {
      throw StateError('Loading $url failed: HTTP ${response.status}.');
    }
    ownUrl = web.URL.createObjectURL(await response.blob().toDart);
  }
  final video = web.HTMLVideoElement()
    ..muted = true
    ..playsInline = true
    ..preload = 'auto'
    ..src = ownUrl ?? url;
  // Attached, though invisible: some browsers decode a detached element's
  // frames lazily or never present them.
  video.style
    ..position = 'fixed'
    ..left = '0'
    ..top = '0'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0'
    ..pointerEvents = 'none';
  web.document.body!.append(video);
  try {
    await Future.any([
      video.onLoadedData.first,
      video.onError.first.then<void>(
        (_) => throw StateError('The browser cannot play $url.'),
      ),
    ]).timeout(const Duration(seconds: 30));
    // Without this check an unseekable file would end after its first frame
    // without a word.
    final seekable = video.seekable;
    if (seekable.length == 0 || seekable.end(seekable.length - 1) <= 0) {
      throw StateError('The browser cannot seek $url frame by frame.');
    }
    final frameSeconds = await _frameSeconds(video);
    return _WebReader(video, frameSeconds, ownUrl);
  } catch (_) {
    video
      ..removeAttribute('src')
      ..remove();
    if (ownUrl != null) web.URL.revokeObjectURL(ownUrl);
    rethrow;
  }
}

/// How long one frame shows, measured from a moment of muted playback; see
/// [frameSecondsFrom].
Future<double> _frameSeconds(web.HTMLVideoElement video) async {
  if (!video.has('requestVideoFrameCallback')) return _fallbackFrameSeconds;
  final times = <(double, int)>[];
  final done = Completer<void>();
  void watch() {
    _VideoCallbacks(video).requestVideoFrameCallback(
      ((JSNumber _, JSObject metadata) {
        final frame = _FrameMetadata(metadata);
        times.add((frame.mediaTime, frame.presentedFrames));
        if (times.length >= 12 || video.ended) {
          if (!done.isCompleted) done.complete();
        } else {
          watch();
        }
      }).toJS,
    );
  }

  watch();
  try {
    await video.play().toDart;
    await done.future.timeout(const Duration(seconds: 5));
  } on Object {
    // A browser that will not play the element keeps the assumed rate.
  } finally {
    video.pause();
  }
  return frameSecondsFrom(times) ?? _fallbackFrameSeconds;
}

final class _WebReader implements VideoFileReader {
  _WebReader(this._video, this._frameSeconds, this._ownUrl);

  final web.HTMLVideoElement _video;
  final double _frameSeconds;

  /// The blob URL [open] made for a file it loaded, released on [close].
  final String? _ownUrl;

  /// Whether a seek waits for the browser's frame callback, whose
  /// presentation time is exact and tells a repeated frame apart.
  late bool _callbacks = _video.has('requestVideoFrameCallback');

  /// The frame slots stepped so far: the next seek goes to the middle of the
  /// next one, so rounding in the browser's seek cannot land on the frame
  /// before or after it.
  var _slot = 0;

  /// When the last frame starts.
  double? _shown;
  var _closed = false;

  @override
  int get rotationDegrees => 0;

  @override
  Duration? get duration => _video.duration.isFinite
      ? Duration(microseconds: (_video.duration * 1e6).round())
      : null;

  @override
  double? get frameRate => 1 / _frameSeconds;

  @override
  Future<VideoFrame?> next() async {
    if (_closed) throw StateError('The video file is closed.');
    while (true) {
      final target = (_slot + 0.5) * _frameSeconds;
      final end = _video.duration;
      if (end.isFinite && target >= end) return null;
      _slot++;
      final presented = await _seek(target);
      // A frame starts at or before the position it is sought at, half a
      // slot before it on the grid. Chromium and WebKit report that start;
      // Firefox reports the seek position itself, which says nothing about
      // the frame, and neither does a late or missing callback. Then the
      // slot's start stands in.
      final exact = presented != null && presented < target - _frameSeconds / 4;
      if (exact && _shown != null && presented <= _shown! + 1e-6) {
        // The same frame again: it lasts longer than one slot.
        continue;
      }
      _shown = exact ? presented : target - _frameSeconds / 2;
      break;
    }
    final bitmap = await web.window.createImageBitmap(_video).toDart;
    return VideoFrame(
      timestampMicroseconds: (_shown! * 1e6).round(),
      width: bitmap.width,
      height: bitmap.height,
      layout: VideoPixelLayout.browser,
      browserFrame: bitmap,
    );
  }

  /// Seeks to [seconds] and returns the presentation time of the frame shown
  /// there, from the browser's frame callback; null once the browser has no
  /// callback the reader can trust.
  Future<double?> _seek(double seconds) async {
    final presented = Completer<double>();
    final callbacks = _callbacks;
    if (callbacks) {
      _VideoCallbacks(_video).requestVideoFrameCallback(
        ((JSNumber _, JSObject metadata) {
          if (!presented.isCompleted) {
            presented.complete(_FrameMetadata(metadata).mediaTime);
          }
        }).toJS,
      );
    }
    final seeked = _video.onSeeked.first;
    _video.currentTime = seconds;
    await seeked.timeout(const Duration(seconds: 10));
    if (!callbacks) return null;
    if (presented.isCompleted) return presented.future;
    try {
      // Presentation follows the seek by a display frame, or by seconds on
      // a loaded machine.
      return await presented.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // A late callback fires with the next seek's, in the same round and
      // with this frame's time, and the reader would skip a frame as a
      // repeat: WebKit did on a loaded CI runner. So the file finishes on
      // the frame grid without callbacks.
      _callbacks = false;
      return null;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _video
      ..pause()
      ..removeAttribute('src')
      ..load()
      ..remove();
    if (_ownUrl case final url?) web.URL.revokeObjectURL(url);
  }
}

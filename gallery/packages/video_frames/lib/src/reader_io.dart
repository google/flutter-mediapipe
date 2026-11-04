import 'package:flutter/services.dart';

import '../video_frames.dart';

const _channel = MethodChannel('video_frames');

/// Opens [path] with the platform's decoder behind the method channel.
Future<VideoFileReader> open(String path) async {
  final info = (await _channel.invokeMapMethod<String, Object?>('open', {
    'path': path,
  }))!;
  return _ChannelReader(info);
}

final class _ChannelReader implements VideoFileReader {
  _ChannelReader(Map<String, Object?> info)
    : _id = info['id']! as int,
      rotationDegrees = info['rotation']! as int,
      duration = switch (info['durationUs']) {
        final int microseconds when microseconds > 0 => Duration(
          microseconds: microseconds,
        ),
        _ => null,
      },
      frameRate = switch (info['frameRate']) {
        final num rate when rate > 0 => rate.toDouble(),
        _ => null,
      };

  final int _id;
  var _closed = false;

  @override
  final int rotationDegrees;

  @override
  final Duration? duration;

  @override
  final double? frameRate;

  @override
  Future<VideoFrame?> next() async {
    if (_closed) throw StateError('The video file is closed.');
    final frame = await _channel.invokeMapMethod<String, Object?>('next', {
      'id': _id,
    });
    if (frame == null) return null;
    final layout = VideoPixelLayout.values.byName(frame['layout']! as String);
    return VideoFrame(
      timestampMicroseconds: frame['timestampUs']! as int,
      width: frame['width']! as int,
      height: frame['height']! as int,
      layout: layout,
      planes: [
        for (final plane in frame['planes']! as List)
          VideoPlane(
            (plane as List)[0] as Uint8List,
            bytesPerRow: plane[1] as int,
            bytesPerPixel: plane[2] as int,
          ),
      ],
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _channel.invokeMethod<void>('close', {'id': _id});
  }
}

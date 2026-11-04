/// Google's audio stream, emulated on its clips mode: the stream in browsers,
/// where Google has none, and the oracle the native stream is tested against.
library;

import 'dart:async';
import 'dart:typed_data';

import '../types.dart';
import 'model_specs.dart';
import 'results.dart';

/// Classifies one clip of interleaved [samples] at [sampleRate] with
/// [channels] values a frame: one result per chunk, as clips mode returns.
typedef ClipClassifier =
    Future<List<AudioClassifierResult>> Function(
      Float32List samples,
      double sampleRate,
      int channels,
    );

/// Frames blocks of any length into the model's windows, classifies each
/// window as a clip, one at a time and in order, and stamps it as Google's
/// stream does.
///
/// At the model's rate a window is exactly the model's input and the result
/// is Google's stream's, to the last bit. At another rate Google's clips mode
/// resamples each window on its own, unlike its streaming resampler: some
/// windows then differ from Google's stream by steps of 1/256 of a score, at
/// most one on speech and up to 22 on a noisy signal, as Google's own clips
/// mode does.
final class EmulatedAudioStream {
  /// Emulates the stream of a model with [_specs] over [_classify],
  /// delivering to [_results].
  EmulatedAudioStream(this._specs, this._classify, this._results)
    : _channels = _specs.channels;

  final AudioModelSpecs _specs;
  final ClipClassifier _classify;
  final AudioStreamResults _results;

  /// Values per buffered frame: a mono model's input is mixed down as each
  /// block arrives, as clips mode mixes it in browsers.
  final int _channels;
  double? _rate;

  /// Frames received and not yet needed by a window: [_buffer] holds frames
  /// from [_bufferStart] of the stream, [_held] of them.
  var _buffer = Float32List(0);
  var _bufferStart = 0;
  var _held = 0;

  /// The next window to classify.
  var _window = 0;
  Future<void> _queue = Future.value();
  var _failed = false;

  /// Adds a checked block that holds samples, and queues every window it
  /// completes.
  void add(AudioData block) {
    _rate ??= block.sampleRate;
    final samples = _channels == 1 && block.channels > 1
        ? monoSamples(block.samples, block.channels)
        : block.samples;
    _append(samples);
    while (_bufferStart + _held >= _end(_window)) {
      final index = _window++;
      final window = _frames(_start(index), _end(index));
      // Frames before the next window's start are never needed again.
      _drop(_start(_window));
      _queue = _queue.then((_) => _run(index, window));
    }
  }

  /// Classifies the windows in flight, then whatever remains short of a
  /// window as the tail, as Google's close does; nothing remains, no tail.
  Future<void> close() async {
    await _queue;
    final start = _start(_window);
    final end = _bufferStart + _held;
    if (_rate == null || end <= start) return;
    await _run(_window++, _frames(start, end));
  }

  Future<void> _run(int index, Float32List window) async {
    if (_failed) return;
    try {
      final chunks = await _classify(window, _rate!, _channels);
      // Clips mode returns a second, padding-only chunk for a window at any
      // rate but the model's, since its resampler's flush runs past the
      // window; the first is the window's.
      if (chunks.isNotEmpty) {
        _results.addWindow(index, chunks.first.classifications);
      }
    } catch (error, stack) {
      _failed = true;
      _results.fail(error, stack);
    }
  }

  /// One window spans `windowSamples * rate / modelRate` input frames, which
  /// need not be whole: window k is the frames from floor(k * span) to
  /// ceil((k + 1) * span).
  int _start(int index) =>
      (index * _specs.windowSamples * _rate! / _specs.sampleRate).floor();

  int _end(int index) =>
      ((index + 1) * _specs.windowSamples * _rate! / _specs.sampleRate).ceil();

  void _append(Float32List samples) {
    final frames = samples.length ~/ _channels;
    if ((_held + frames) * _channels > _buffer.length) {
      final grown = Float32List(
        ((_held + frames) * 2 + _specs.windowSamples) * _channels,
      )..setRange(0, _held * _channels, _buffer);
      _buffer = grown;
    }
    _buffer.setRange(_held * _channels, (_held + frames) * _channels, samples);
    _held += frames;
  }

  Float32List _frames(int start, int end) => Float32List.fromList(
    Float32List.sublistView(
      _buffer,
      (start - _bufferStart) * _channels,
      (end - _bufferStart) * _channels,
    ),
  );

  void _drop(int before) {
    final count = before - _bufferStart;
    if (count <= 0) return;
    _buffer.setRange(
      0,
      (_held - count) * _channels,
      _buffer,
      count * _channels,
    );
    _bufferStart = before;
    _held -= count;
  }
}

/// [samples] of [channels] interleaved values a frame, averaged to one.
Float32List monoSamples(Float32List samples, int channels) {
  if (channels == 1) return Float32List.fromList(samples);
  final frames = samples.length ~/ channels;
  final mono = Float32List(frames);
  for (var frame = 0; frame < frames; frame++) {
    var sum = 0.0;
    for (var channel = 0; channel < channels; channel++) {
      sum += samples[frame * channels + channel];
    }
    mono[frame] = sum / channels;
  }
  return mono;
}

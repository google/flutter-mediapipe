/// The hooks through which this package's web code runs the audio tasks on
/// Google's browser runtime.
library;

import 'dart:typed_data';

import 'speech_runners.dart';
import 'speech_types.dart';

/// Google's Audio Classifier, created and run by a platform backend.
abstract interface class AudioTaskBackend {
  /// Classifies mono [samples] at [sampleRate] and returns Google's
  /// JavaScript results (one per chunk), as JSON values.
  Future<List<Object?>> classify(Float32List samples, double sampleRate);

  /// Waits for queued requests, then closes Google's task.
  Future<void> dispose();
}

/// Creates Google's Audio Classifier from `options` named as in Google's
/// JavaScript API, plus `modelBytes` (a `Uint8List`) or `modelPath` (a URL).
///
/// Installed by this package's web code in browsers, where Google's runtime
/// has no audio stream, so the package emulates the stream on its clips
/// mode; null where the package runs Google's runtime itself.
Future<AudioTaskBackend> Function(Map<String, Object?> options)?
audioTaskBackendFactory;

/// Opens Google's Audio Transcriber in browsers; null elsewhere, where the
/// package opens Google's native task itself.
Future<AudioTranscriberRunner> Function(AudioTranscriberOptions options)?
audioTranscriberOpener;

/// Opens Google's Text to Speech in browsers; null elsewhere, where the
/// package opens Google's native task itself.
Future<TextToSpeechRunner> Function(TextToSpeechOptions options)?
textToSpeechOpener;

/// Whether the browser runs on a Mac, which its WebGPU adapter does not say:
/// Safari names the same adapter on iPhones and iPads.
///
/// Set by this package's web code; false elsewhere.
bool browserOnMac = false;

/// Browsers have no native runtime: Audio Classifier runs through the
/// registered browser plugin, so reaching this means it did not register.
library;

import 'package:mediapipe_core/platform_interface.dart'
    show pluginNotRegistered;

import 'runner.dart';
import 'stream/results.dart';
import 'types.dart';

final _missing = pluginNotRegistered('mediapipe_audio');

/// The native Audio Classifier; browsers have none.
Future<AudioClassifierRunner> openNativeAudioClassifier(
  AudioClassifierOptions options,
) async => throw _missing;

/// The native audio stream; browsers have none.
Future<AudioStreamRunner> openNativeAudioStream(
  AudioClassifierOptions options,
  AudioStreamResults results,
) async => throw _missing;

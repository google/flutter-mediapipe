import 'package:mediapipe_audio/mediapipe_audio.dart';

Future<bool> audioAvailable() async {
  final support = await queryAudioClassifierCapabilities();
  return support.supportedDelegates.contains(Delegate.cpu);
}

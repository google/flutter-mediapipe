import 'package:mediapipe_audio/mediapipe_audio.dart';

Future<void> removeDownloadedModels() async {
  final store = ModelStore();
  final before = await store.find(AudioModels.yamnet);
  print('Before: ${before == null ? 'not on this device' : 'ready'}');
  await store.clear();
  final after = await store.find(AudioModels.yamnet);
  print('After: ${after == null ? 'not on this device' : 'ready'}');
}

import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> prepareModels() async {
  final store = ModelStore();
  await store.prefetch(TextModels.bertClassifier);
  final source = await store.get(TextModels.bertClassifier);
  print(source.path); // A file on native platforms; `bytes` in browsers.
}

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<double> compareImages(VisionImage first, VisionImage second) async {
  final embedder = await ImageEmbedder.create(
    ImageEmbedderOptions(model: VisionModels.imageEmbedder, l2Normalize: true),
  );
  try {
    final a = await embedder.embed(first);
    final b = await embedder.embed(second);
    return ImageEmbedder.cosineSimilarity(
      a.embeddings.first,
      b.embeddings.first,
    );
  } finally {
    await embedder.dispose();
  }
}

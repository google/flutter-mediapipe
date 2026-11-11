import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> compareCompact(VisionImage first, VisionImage second) async {
  final embedder = await ImageEmbedder.create(
    ImageEmbedderOptions(model: VisionModels.imageEmbedder, quantize: true),
  );
  try {
    final a = (await embedder.embed(first)).embeddings.first;
    final b = (await embedder.embed(second)).embeddings.first;
    print('${a.quantizedEmbedding!.length} bytes each');
    final similarity = ImageEmbedder.cosineSimilarity(a, b);
    print('Similarity: ${similarity.toStringAsFixed(2)}');
  } finally {
    await embedder.dispose();
  }
}

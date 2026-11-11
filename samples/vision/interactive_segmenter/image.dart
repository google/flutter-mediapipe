import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<ConfidenceMask> selectObject(VisionImage image) async {
  final segmenter = await InteractiveSegmenter.create(
    InteractiveSegmenterOptions(model: VisionModels.interactiveSegmenter),
  );
  try {
    await segmenter.setImage(image);
    return await segmenter.segment([
      Stroke(
        brushMode: BrushMode.positive,
        points: [
          const NormalizedKeypoint(x: 0.45, y: 0.5),
          const NormalizedKeypoint(x: 0.55, y: 0.5),
        ],
      ),
    ]);
  } finally {
    await segmenter.dispose();
  }
}

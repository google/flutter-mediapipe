import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> countFacesFast(VisionImage image) async {
  final support = await queryFaceLandmarkerCapabilities();
  var delegate = support.supportedDelegates.contains(Delegate.gpu)
      ? Delegate.gpu
      : Delegate.cpu;
  Future<FaceLandmarker> create() => FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      delegate: delegate,
    ),
  );
  FaceLandmarker task;
  try {
    task = await create();
  } on TaskException catch (error) {
    if (!error.gpuUnavailable) rethrow;
    delegate = Delegate.cpu;
    task = await create();
  }
  try {
    final result = await task.detect(image);
    final faces = result.faceLandmarks.length;
    print('Faces found on the ${delegate.name}: $faces');
  } finally {
    await task.dispose();
  }
}

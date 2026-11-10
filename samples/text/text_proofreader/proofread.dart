import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> proofread() async {
  final task = await TextProofreader.create(
    TextProofreaderOptions(model: TextModels.proofreader),
  );
  try {
    final result = await task.proofread('She go home.');
    print(result.proofreadText);
    for (final edit in result.corrections) {
      print('${edit.type.name}: ${edit.text}');
    }
    await for (final update in task.proofreadStream(
      'I recieved your mesage.',
    )) {
      if (update.chunk != null) print(update.chunk);
      if (update.done) print(update.corrections);
    }
  } finally {
    await task.dispose();
  }
}

import 'package:mediapipe_text/mediapipe_text.dart';

Future<bool> canSummarize() async {
  final support = await queryTextSummarizerCapabilities();
  return support.supportedDelegates.contains(Delegate.cpu);
}

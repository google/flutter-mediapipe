import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/speech_page.dart';

const _platform = TaskPlatform(
  operatingSystem: 'macos',
  architecture: 'arm64',
  version: '15.0',
);

void main() {
  test(
    'the Text to Speech page opens on the CPU where Kokoro gets the GPU',
    () {
      // Text to Speech offers the GPU here for Kokoro, but the page speaks
      // with Phonon, which create refuses on the GPU.
      expect(
        textToSpeechCapabilitiesForPlatform(_platform).supportedDelegates,
        contains(Delegate.gpu),
      );
      final task = supportedTasks(_platform, {'text_to_speech'}).single;
      final delegates = speechPageDelegates(task, _platform);
      expect(delegates, [Delegate.cpu]);
      expect(preferredDelegate(delegates), Delegate.cpu);
    },
  );
}

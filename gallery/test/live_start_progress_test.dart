import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_gallery/live/live_start_progress.dart';

void main() {
  group('LiveStartProgress', () {
    test('cannot measure a model of unknown size', () {
      final progress = LiveStartProgress();
      expect(progress.step, 'Loading model');
      expect(progress.value, isNull);
      expect(progress.detail, isNull);
      expect(progress.summary, 'Loading model');

      expect(progress.modelReceived(5000000, null), isFalse);
      expect(progress.value, isNull);
    });

    test('the download fills the first 80%', () {
      final progress = LiveStartProgress();
      expect(progress.modelReceived(0, 8000000), isTrue);
      expect(progress.step, 'Downloading model');
      expect(progress.percent, 0);

      expect(progress.modelReceived(4000000, 8000000), isTrue);
      expect(progress.percent, 40);
      expect(progress.detail, '4.0 / 8.0 MB');
      expect(progress.summary, 'Downloading model 40%');

      // A response larger than the recorded size stays within the download.
      progress.modelReceived(9000000, 8000000);
      expect(progress.percent, 80);
    });

    test('asks for a redraw per whole percent', () {
      final progress = LiveStartProgress()..modelReceived(0, 100000000);
      expect(progress.modelReceived(100, 100000000), isFalse);
      expect(progress.modelReceived(2000000, 100000000), isTrue);
    });

    test('names the first unfinished step, in any order of finishing', () {
      final progress = LiveStartProgress()
        ..modelReceived(8000000, 8000000)
        ..cameraOpen();
      expect(progress.step, 'Downloading model');

      progress.modelLoaded();
      expect(progress.step, 'Starting MediaPipe');
      expect(progress.percent, 80);
      expect(progress.detail, isNull);

      progress.taskOpen();
      expect(progress.step, 'Warming up');
      expect(progress.percent, 95);
    });

    test('waits for a camera that is slower than the task', () {
      final progress = LiveStartProgress()
        ..modelLoaded()
        ..taskOpen();
      expect(progress.step, 'Waiting for camera');
      expect(progress.percent, 90);
    });

    test('restart clears an earlier start', () {
      final progress = LiveStartProgress()
        ..modelReceived(8000000, 8000000)
        ..modelLoaded()
        ..taskOpen()
        ..cameraOpen()
        ..restart();
      expect(progress.step, 'Loading model');
      expect(progress.value, isNull);
    });
  });

  group('LiveStartCard', () {
    Future<void> pump(WidgetTester tester, LiveStartProgress progress) =>
        tester.pumpWidget(MaterialApp(home: LiveStartCard(progress)));

    LinearProgressIndicator bar(WidgetTester tester) =>
        tester.widget(find.byType(LinearProgressIndicator));

    testWidgets('shows a download by percent and megabytes', (tester) async {
      await pump(tester, LiveStartProgress()..modelReceived(4000000, 8000000));
      expect(find.text('Downloading model...'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('4.0 / 8.0 MB'), findsOneWidget);
      expect(bar(tester).value, closeTo(.4, 1e-9));
    });

    testWidgets('moves without a percent when the size is unknown', (
      tester,
    ) async {
      await pump(tester, LiveStartProgress());
      expect(find.text('Loading model...'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(bar(tester).value, isNull);
    });

    testWidgets('drops the megabytes once the model is in', (tester) async {
      await pump(
        tester,
        LiveStartProgress()
          ..modelReceived(8000000, 8000000)
          ..modelLoaded(),
      );
      expect(find.text('Starting MediaPipe...'), findsOneWidget);
      expect(find.textContaining('MB'), findsNothing);
    });
  });
}

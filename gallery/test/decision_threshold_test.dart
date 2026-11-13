import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_gallery/live/task_settings.dart';
import 'package:mediapipe_gallery/live/task_settings_panel.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

void main() {
  // Google's guide gives the threshold's default, 0.5, and its web demo's
  // slider runs from 0.05 to 0.95 in steps of 0.05.
  testWidgets('the Yes Threshold runs from 0.05 to 0.95 in twentieths', (
    tester,
  ) async {
    final settings = taskSettings['decision_maker']!;
    final values = TaskSettingValues('decision_maker');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              TaskSettingsPanel(
                settings: settings,
                values: values,
                delegates: const [Delegate.cpu],
                delegate: Delegate.cpu,
                enabled: true,
                onChanged: (key, value) => values[key] = value,
                onDelegate: (_) {},
                models: const [],
                model: null,
                uploaded: null,
                modelStatus: null,
                onModel: (_) {},
                onUpload: null,
              ),
            ],
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('setting-threshold')),
    );
    expect((slider.min, slider.max, slider.divisions), (0.05, 0.95, 18));
    expect(slider.value, 0.5);
    expect(find.text('Yes Threshold'), findsOneWidget);
    expect(find.text('0.50'), findsOneWidget);
  });

  test('every other share still runs from 0 to 1', () {
    for (final MapEntry(key: task, value: settings) in taskSettings.entries) {
      for (final setting in settings.whereType<ShareSetting>()) {
        if (task == 'decision_maker') continue;
        expect(
          (setting.min, setting.max),
          (0, 1),
          reason: '$task ${setting.key}',
        );
      }
    }
  });
}

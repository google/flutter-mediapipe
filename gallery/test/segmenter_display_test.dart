import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/live/mask_overlay.dart';
import 'package:mediapipe_gallery/live/task_models.dart';
import 'package:mediapipe_gallery/live/task_settings.dart';
import 'package:mediapipe_gallery/live/task_settings_panel.dart';

void main() {
  final result = ImageSegmenterResult(
    categoryMask: CategoryMask(
      width: 3,
      height: 1,
      categories: Uint8List.fromList([0, 15, 200]),
    ),
    confidenceMasks: [
      ConfidenceMask(
        width: 3,
        height: 1,
        confidence: Float32List.fromList([1, 0, 0]),
      ),
      ConfidenceMask(
        width: 3,
        height: 1,
        confidence: Float32List.fromList([0, 0.5, 1]),
      ),
    ],
    labels: const ['background', 'person'],
    imageWidth: 3,
    imageHeight: 1,
  );

  test('category mask pixels take Google legend colors', () {
    final pixels = maskPixels(result, (confidence: false, selectedClass: 0))!;
    expect((pixels.width, pixels.height), (3, 1));
    expect(pixels.rgba, [
      // Background, Google Blue.
      66, 133, 244, 255,
      // Class 15, a person in cyan.
      0, 255, 255, 255,
      // Past the table: transparent.
      0, 0, 0, 0,
    ]);
  });

  test('confidence mask pixels are blue at the chosen class confidence', () {
    final pixels = maskPixels(result, (confidence: true, selectedClass: 1))!;
    expect(pixels.rgba, [0, 0, 0, 0, 0, 0, 128, 128, 0, 0, 255, 255]);
    expect(
      maskPixels(result, (confidence: true, selectedClass: 2)),
      isNull,
      reason: 'the model has no third class',
    );
  });

  testWidgets('segmenter settings follow Google demo', (tester) async {
    final values = TaskSettingValues('image_segmenter');
    final changes = <String, Object>{};
    Widget panel() => MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ListView(
            children: [
              TaskSettingsPanel(
                settings: taskSettings['image_segmenter']!,
                values: values,
                delegates: const [Delegate.cpu],
                delegate: Delegate.cpu,
                enabled: true,
                onChanged: (key, value) => setState(() {
                  values[key] = value;
                  changes[key] = value;
                }),
                onDelegate: (_) {},
                models: taskModels['image_segmenter']!,
                model: null,
                uploaded: null,
                modelStatus: null,
                onModel: (_) {},
                onUpload: () {},
                standardModel: 'DeepLab V3',
                labels: const ['background', 'person'],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(panel());

    // The bundled model is listed first by Google's name for it.
    expect(find.text('DeepLab V3'), findsOneWidget);
    expect(find.text('Output Type'), findsOneWidget);
    expect(find.text('Category Mask'), findsOneWidget);
    expect(find.text('Opacity'), findsOneWidget);
    expect(find.text('0.50'), findsOneWidget);
    expect(find.text('Select Class'), findsNothing);
    expect(find.text('Connections'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('setting-outputConfidenceMasks')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confidence Mask').last);
    await tester.pumpAndSettle();

    expect(changes['outputConfidenceMasks'], 1);
    expect(find.text('Select Class'), findsOneWidget);
    expect(find.text('background'), findsOneWidget);
  });

  test('only the output type rebuilds the segmenter', () {
    final display = {
      for (final setting in taskSettings['image_segmenter']!)
        setting.key: setting.display,
    };
    expect(display, {
      'outputConfidenceMasks': false,
      'confidenceClass': true,
      'opacity': true,
    });
  });
}

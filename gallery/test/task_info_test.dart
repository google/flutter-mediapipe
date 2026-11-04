import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/ui/design.dart';
import 'package:mediapipe_gallery/ui/workspace.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:url_launcher/link.dart';

void main() {
  testWidgets('the task guide is a link that opens outside the gallery', (
    tester,
  ) async {
    final task = supportedTasks(
      const TaskPlatform(
        operatingSystem: 'macos',
        architecture: 'arm64',
        version: '15',
      ),
      const {'face_detector'},
    ).single;
    await tester.pumpWidget(
      MaterialApp(
        theme: galleryTheme(Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTaskInfo(context, task),
            child: const Text('Info'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();

    final link = tester.widget<Link>(find.byType(Link));
    expect(link.target, LinkTarget.blank);
    expect(
      link.uri,
      Uri.parse(
        'https://ai.google.dev/edge/mediapipe/solutions/vision/face_detector',
      ),
    );
  });
}

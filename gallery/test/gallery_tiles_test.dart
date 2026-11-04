import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/gallery_tiles.dart';

void main() {
  testWidgets('gallery tile finder ignores a matching sidebar title', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const Text('Face Landmarker'),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('gallery-home'),
                  child: Column(
                    children: [
                      const SizedBox(height: 1200),
                      TextButton(
                        onPressed: () => tapped = true,
                        child: const Text('Face Landmarker'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Face Landmarker'), findsNWidgets(2));
    final tile = await scrollToGalleryTile(tester, 'Face Landmarker');
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    expect(tapped, isTrue);
  });
}

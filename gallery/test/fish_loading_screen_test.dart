import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/fish_game_page.dart';

void main() {
  // The sea a Galaxy S24 (360 points wide) gave the loading screen on Test
  // Lab, where the screen overflowed by 11 points with this status.
  testWidgets('the loading screen fits the sea of a 360-point-wide phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 302,
            height: 181.2,
            child: FishLoadingScreen(
              status:
                  'Loading EmbeddingGemma 2 (388 MB). The first game '
                  'downloads it; after that it loads from this device.',
              seconds: 12,
              starting: true,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Loading EmbeddingGemma 2'), findsOneWidget);
  });
}

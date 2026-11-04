import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Waits for the gallery's Home page, then scrolls the card titled [title]
/// into view and returns the finder for its title.
///
/// A short phone shows only the first few cards: a Galaxy S24 shows three,
/// and Hand Landmarker is the fourth.
Future<Finder> scrollToGalleryTile(WidgetTester tester, String title) async {
  final home = find.byKey(const ValueKey('gallery-home'));
  // On a cold Windows runner unpacking assets can outlast the first few
  // frames. Wait for the scrollable child too, so scrolling never receives a
  // finder for a gallery that has not finished building.
  final scrollable = find.descendant(
    of: home,
    matching: find.byType(Scrollable),
  );
  for (
    var i = 0;
    i < 600 && (home.evaluate().isEmpty || scrollable.evaluate().isEmpty);
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(home, findsOneWidget, reason: 'Home gallery did not load');
  expect(scrollable, findsWidgets, reason: 'Home gallery is not scrollable');
  // The wide layout also shows this name in the sidebar. Select the Home
  // page's card so the finder remains unique on desktop.
  final tile = find.descendant(of: home, matching: find.text(title));
  await tester.scrollUntilVisible(tile, 300, scrollable: scrollable.first);
  return tile;
}

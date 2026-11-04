import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/ui/components.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

/// Selects [delegate] in the settings once the page enables it; a tap on a
/// disabled control would be ignored. Phones keep settings in a bottom sheet,
/// which is opened for the tap and closed again.
Future<void> tapDelegate(WidgetTester tester, Delegate delegate) async {
  final control = find.byWidgetPredicate(
    (widget) => widget is Segmented<Delegate>,
  );
  final sheet =
      control.evaluate().isEmpty &&
      find.byTooltip('Settings').evaluate().isNotEmpty;
  if (sheet) {
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
  }
  final segment = find.byKey(ValueKey('delegate-${delegate.name}'));
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (true) {
    await tester.pump();
    final found = control.evaluate().isNotEmpty;
    // The control lists only the delegates the page offers.
    if (found && segment.evaluate().isEmpty) {
      fail('The page offers no ${delegate.name}: ${screenText(tester)}');
    }
    if (found &&
        tester.widget<Segmented<Delegate>>(control).onChanged != null) {
      break;
    }
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'The CPU/GPU control stayed ${found ? 'disabled' : 'missing'} '
        'for ${delegate.name}: ${screenText(tester)}',
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  await tester.ensureVisible(segment);
  await tester.tap(segment);
  await tester.pump();
  if (sheet) {
    // A long sheet scrolls its Close button out of the list to reach the
    // control, so its route is closed directly.
    Navigator.of(tester.element(segment)).pop();
    await settle(tester);
  }
}

/// Lets the sheet finish animating. Unlike pumpAndSettle it gives up after a
/// few seconds, because a live camera preview never stops scheduling frames.
/// Pumps until no frame is scheduled, for at most three seconds.
Future<void> settle(WidgetTester tester) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  do {
    await tester.pump(const Duration(milliseconds: 100));
  } while (tester.binding.hasScheduledFrame && DateTime.now().isBefore(end));
}

/// The page's visible text, for failure messages.
String screenText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data)
    .whereType<String>()
    .where((text) => text.trim().isNotEmpty)
    .join(' | ');

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/speed_history.dart';
import 'package:mediapipe_gallery/ui/components.dart';
import 'package:mediapipe_gallery/ui/design.dart';
import 'package:mediapipe_gallery/ui/speed_chart.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

void main() {
  testWidgets('the CPU and GPU checkboxes control the chart lines', (
    tester,
  ) async {
    final history = SpeedHistory()
      ..add(Delegate.cpu, 10, Duration.zero)
      ..add(Delegate.gpu, 5, const Duration(milliseconds: 100));
    await tester.pumpWidget(
      MaterialApp(
        theme: galleryTheme(Brightness.dark),
        home: Scaffold(
          body: StatsCard(
            history: history,
            delegates: const [Delegate.cpu, Delegate.gpu],
          ),
        ),
      ),
    );

    SpeedChartPainter chart() =>
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byType(StatsCard),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter!
            as SpeedChartPainter;

    expect(chart().shown, [Delegate.cpu, Delegate.gpu]);
    await tester.tap(find.byKey(const ValueKey('stats-gpu')));
    await tester.pump();
    expect(chart().shown, [Delegate.cpu]);
    await tester.tap(find.byKey(const ValueKey('stats-cpu')));
    await tester.pump();
    expect(chart().shown, isEmpty);
    await tester.tap(find.byKey(const ValueKey('stats-gpu')));
    await tester.pump();
    expect(chart().shown, [Delegate.gpu]);
  });

  testWidgets('the switch names the other delegate and asks for it', (
    tester,
  ) async {
    final asked = <Delegate>[];
    for (final (running, label, other) in [
      (Delegate.cpu, 'Switch to GPU', Delegate.gpu),
      (Delegate.gpu, 'Switch to CPU', Delegate.cpu),
    ]) {
      await _pumpCard(
        tester,
        StatsCard(
          history: SpeedHistory(),
          delegates: const [Delegate.cpu, Delegate.gpu],
          delegate: running,
          onSwitchDelegate: asked.add,
        ),
      );
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      expect(asked.last, other);
    }
    expect(asked, [Delegate.gpu, Delegate.cpu]);
  });

  testWidgets('a task with one delegate has nothing to switch to', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      StatsCard(
        history: SpeedHistory(),
        delegates: const [Delegate.cpu],
        delegate: Delegate.cpu,
        onSwitchDelegate: (_) => fail('no other delegate'),
      ),
    );
    expect(find.byKey(const ValueKey('stats-switch')), findsNothing);
  });

  testWidgets('the switch is disabled while the task restarts', (tester) async {
    await _pumpCard(
      tester,
      StatsCard(
        history: SpeedHistory(),
        delegates: const [Delegate.cpu, Delegate.gpu],
        delegate: Delegate.gpu,
      ),
    );
    final button = find.byKey(const ValueKey('stats-switch'));
    expect(button, findsOneWidget);
    expect(tester.widget<OutlineButton>(button).onPressed, isNull);
    // The label merges into the button's own semantics node.
    final node = tester.getSemantics(find.text('Switch to CPU'));
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(button);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset clears the chart', (tester) async {
    final history = SpeedHistory()
      ..add(Delegate.cpu, 10, Duration.zero)
      ..add(Delegate.cpu, 9, const Duration(milliseconds: 100));
    await _pumpCard(
      tester,
      StatefulBuilder(
        builder: (context, setState) => StatsCard(
          history: history,
          delegates: const [Delegate.cpu, Delegate.gpu],
          delegate: Delegate.cpu,
          onSwitchDelegate: (_) {},
          onReset: () => setState(history.clear),
        ),
      ),
    );
    expect(find.text('Waiting for frames'), findsNothing);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(history.length, 0);
    expect(find.text('Waiting for frames'), findsOneWidget);
  });
}

Future<void> _pumpCard(WidgetTester tester, Widget card) => tester.pumpWidget(
  MaterialApp(
    theme: galleryTheme(Brightness.dark),
    home: Scaffold(body: card),
  ),
);

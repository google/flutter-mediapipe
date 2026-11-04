import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart' show Delegate;

import '../live/speed_history.dart';
import 'components.dart';
import 'design.dart';

/// The Stats card under a live feed: every frame's inference time since the
/// camera started, a line per delegate, each shown or hidden by its checkbox.
/// It can also switch the task to the other delegate, to add its line, and
/// clear the chart.
class StatsCard extends StatefulWidget {
  const StatsCard({
    super.key,
    required this.history,
    required this.delegates,
    this.delegate,
    this.onSwitchDelegate,
    this.onReset,
    this.onClose,
  });

  final SpeedHistory history;

  /// The delegates the page offers, in the order their entries appear.
  final List<Delegate> delegates;

  /// The delegate the task runs on. With two [delegates], the card offers
  /// to switch to the other one.
  final Delegate? delegate;

  /// Switches the task to the delegate it is given; null disables the switch,
  /// as while the task restarts.
  final ValueChanged<Delegate>? onSwitchDelegate;

  /// Clears the chart; null hides the button.
  final VoidCallback? onReset;

  /// Closes the dialog that shows this card on phones.
  final VoidCallback? onClose;

  @override
  State<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<StatsCard> {
  final _hidden = <Delegate>{};

  /// The crosshair's x in the chart, while a pointer is on it.
  double? _pointer;

  void _point(double? x) => setState(() => _pointer = x);

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final history = widget.history;
    final colors = {Delegate.cpu: c.seriesCpu, Delegate.gpu: c.seriesGpu};
    final muted = TextStyle(color: c.muted, fontSize: Sizes.xs);
    final shown = [
      for (final delegate in widget.delegates)
        if (!_hidden.contains(delegate)) delegate,
    ];
    final other = widget.delegates.length == 2 && widget.delegate != null
        ? widget.delegates.firstWhere((d) => d != widget.delegate)
        : null;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    for (final delegate in widget.delegates)
                      SeriesToggle(
                        key: ValueKey('stats-${delegate.name}'),
                        label: _name(delegate),
                        color: colors[delegate]!,
                        // One series needs no switch: the title names it.
                        checked: widget.delegates.length > 1
                            ? !_hidden.contains(delegate)
                            : null,
                        milliseconds: history.recent(delegate),
                        droppedPerSecond: history.droppedPerSecond(delegate),
                        onChanged: (on) => setState(
                          () => on
                              ? _hidden.remove(delegate)
                              : _hidden.add(delegate),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.onClose case final close?) ...[
                const SizedBox(width: 10),
                OutlineButton(
                  icon: LucideIcons.x,
                  tooltip: 'Close stats',
                  onPressed: close,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: history.length == 0
                ? Center(child: Text('Waiting for frames', style: muted))
                : MouseRegion(
                    onHover: (event) => _point(event.localPosition.dx),
                    onExit: (_) => _point(null),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _point(details.localPosition.dx),
                      onTapUp: (_) => _point(null),
                      onTapCancel: () => _point(null),
                      onHorizontalDragUpdate: (details) =>
                          _point(details.localPosition.dx),
                      onHorizontalDragEnd: (_) => _point(null),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: SpeedChartPainter(
                          history: history,
                          shown: shown,
                          colors: colors,
                          pointer: _pointer,
                          text: DefaultTextStyle.of(context).style.copyWith(
                            color: c.muted,
                            fontSize: Sizes.xs,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          ink: c.text,
                          grid: c.line,
                          baseline: c.hoverLine,
                          surface: c.surface,
                          tooltip: c.surface2,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('Seconds on each delegate', style: muted),
              // A narrow phone dialog stacks the buttons.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.onReset case final reset?)
                    OutlineButton(
                      key: const ValueKey('stats-reset'),
                      icon: LucideIcons.rotateCcw,
                      label: 'Reset',
                      tooltip: 'Clear the chart',
                      fontSize: Sizes.sm,
                      onPressed: reset,
                    ),
                  if (other != null)
                    OutlineButton(
                      key: const ValueKey('stats-switch'),
                      icon: LucideIcons.arrowLeftRight,
                      label: 'Switch to ${_name(other)}',
                      tooltip: 'Run the task on ${_name(other)}',
                      fontSize: Sizes.sm,
                      onPressed: switch (widget.onSwitchDelegate) {
                        final onSwitch? => () => onSwitch(other),
                        null => null,
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _name(Delegate delegate) =>
      delegate == Delegate.gpu ? 'GPU' : 'CPU';
}

/// A legend entry: a checkbox in the series color when [checked] is not null,
/// the delegate, its recent inference time and the camera frames it recently
/// dropped per second.
class SeriesToggle extends StatelessWidget {
  const SeriesToggle({
    super.key,
    required this.label,
    required this.color,
    required this.checked,
    required this.milliseconds,
    this.droppedPerSecond,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final bool? checked;
  final double? milliseconds;
  final double? droppedPerSecond;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final on = checked ?? true;
    // A check mark in white or ink, whichever the fill needs.
    final mark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF101314);
    final entry = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (checked == null)
          // The line's own key when there is nothing to switch.
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: on ? color : Colors.transparent,
              border: Border.all(color: on ? color : c.hoverLine, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: on ? Icon(LucideIcons.check, size: 12, color: mark) : null,
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: on ? c.text : c.muted,
            fontSize: Sizes.sm,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (milliseconds case final ms?) ...[
          const SizedBox(width: 7),
          Text(
            '${ms.toStringAsFixed(1)} ms',
            style: TextStyle(
              color: c.muted,
              fontSize: Sizes.sm,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (droppedPerSecond case final dropped?) ...[
          const SizedBox(width: 7),
          Text(
            '${dropped.toStringAsFixed(1)} dropped/s',
            style: TextStyle(
              color: c.muted,
              fontSize: Sizes.sm,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
    if (checked == null) return entry;
    return Semantics(
      checked: on,
      label: label,
      onTap: () => onChanged(!on),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Sizes.radiusSmall),
        onTap: () => onChanged(!on),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: entry,
        ),
      ),
    );
  }
}

/// Inference time over time as a torrent client draws speed: a line and a
/// light wash per shown delegate, its latest frame marked, and a crosshair
/// that reads every line at the pointer.
class SpeedChartPainter extends CustomPainter {
  SpeedChartPainter({
    required this.history,
    required this.shown,
    required this.colors,
    required this.pointer,
    required this.text,
    required this.ink,
    required this.grid,
    required this.baseline,
    required this.surface,
    required this.tooltip,
  }) : _samples = history.length;

  final SpeedHistory history;

  /// The delegates whose lines are drawn.
  final List<Delegate> shown;
  final Map<Delegate, Color> colors;

  /// The crosshair's x, or null without a pointer.
  final double? pointer;
  final TextStyle text;
  final Color ink;
  final Color grid;
  final Color baseline;
  final Color surface;
  final Color tooltip;
  final int _samples;

  static const _left = 46.0;
  static const _right = 12.0;
  static const _top = 8.0;
  static const _bottom = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;
    final series = [
      for (final delegate in shown)
        if (history.chartSamples(delegate).isNotEmpty) delegate,
    ];
    final span = math.max(10.0, history.durationSeconds);
    // Scale to the values the user can actually see. The chart draws
    // quarter-second averages, so a raw startup spike must not leave the
    // visible lines compressed against an unrelated ceiling.
    final range = math.max(15.0, history.chartPeak(series) * 1.15);
    final yStep = _step(range, 4, const [1, 2, 2.5, 5]);
    final yMax = (range / yStep).ceil() * yStep;
    Offset at(SpeedSample sample) => Offset(
      plot.left + sample.seconds / span * plot.width,
      plot.bottom - sample.milliseconds / yMax * plot.height,
    );

    // Recessive hairlines at clean values; the zero line a step stronger.
    final hairline = Paint()..strokeWidth = 1;
    for (var value = 0.0; value <= yMax + yStep / 2; value += yStep) {
      final y = (plot.bottom - value / yMax * plot.height).roundToDouble() + .5;
      hairline.color = value == 0 ? baseline : grid;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), hairline);
      _label(
        canvas,
        '${_number(value)} ms',
        Offset(plot.left - 8, y),
        right: true,
      );
    }
    final xStep = _step(span, 6, const [1, 2, 5, 10, 15, 30, 60]);
    for (var value = 0.0; value <= span + 1e-9; value += xStep) {
      final x = plot.left + value / span * plot.width;
      _label(
        canvas,
        _seconds(value),
        Offset(x, plot.bottom + 12),
        centre: true,
      );
    }

    for (final delegate in series) {
      final values = history.chartSamples(delegate);
      final color = colors[delegate]!;
      final points = [for (final sample in values) at(sample)];
      if (points.length > 1) {
        final line = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          line.lineTo(point.dx, point.dy);
        }
        final area = Path.from(line)
          ..lineTo(points.last.dx, plot.bottom)
          ..lineTo(points.first.dx, plot.bottom)
          ..close();
        canvas.drawPath(area, Paint()..color = color.withValues(alpha: .1));
        canvas.drawPath(
          line,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      _dot(canvas, points.last, color);
    }

    // Read the nearest recorded interval on each line at the pointer.
    if (pointer case final x? when x >= plot.left && x <= plot.right) {
      final seconds = (x - plot.left) / plot.width * span;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = baseline
          ..strokeWidth = 1,
      );
      final rows = <(Color, String)>[];
      for (final delegate in series) {
        final value = _nearest(history.chartSamples(delegate), seconds);
        if (value == null) continue;
        _dot(canvas, at(value), colors[delegate]!);
        rows.add((
          colors[delegate]!,
          '${delegate == Delegate.gpu ? 'GPU' : 'CPU'}  '
              '${value.milliseconds.toStringAsFixed(1)} ms',
        ));
      }
      if (rows.isNotEmpty) {
        _tooltip(canvas, plot, x, _seconds(seconds, precise: true), rows);
      }
    }
  }

  /// The closest quarter-second value in a sorted delegate series.
  SpeedSample? _nearest(List<SpeedSample> values, double seconds) {
    var low = 0;
    var high = values.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (values[middle].seconds < seconds) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final before = low > 0 ? values[low - 1] : null;
    final after = low < values.length ? values[low] : null;
    if (before == null) return after;
    if (after == null) return before;
    return seconds - before.seconds <= after.seconds - seconds ? before : after;
  }

  /// A filled end dot with a ring of the card's surface.
  void _dot(Canvas canvas, Offset centre, Color color) {
    canvas
      ..drawCircle(centre, 6, Paint()..color = surface)
      ..drawCircle(centre, 4, Paint()..color = color);
  }

  void _label(
    Canvas canvas,
    String value,
    Offset anchor, {
    bool right = false,
    bool centre = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: text),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right
        ? anchor.dx - painter.width
        : centre
        ? anchor.dx - painter.width / 2
        : anchor.dx;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  void _tooltip(
    Canvas canvas,
    Rect plot,
    double x,
    String title,
    List<(Color, String)> rows,
  ) {
    TextPainter layout(String value, Color color) => TextPainter(
      text: TextSpan(
        text: value,
        style: text.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final heading = layout(title, text.color!);
    final lines = [for (final row in rows) layout(row.$2, ink)];
    const pad = 8.0;
    const key = 14.0;
    const gap = 4.0;
    final width =
        [
          heading.width,
          for (final line in lines) key + line.width,
        ].fold<double>(0, math.max) +
        pad * 2;
    final height =
        heading.height +
        lines.fold<double>(0, (sum, line) => sum + line.height + gap) +
        pad * 2;
    // Beside the crosshair, on whichever side has room.
    final left = x + 10 + width <= plot.right ? x + 10 : x - 10 - width;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(math.max(plot.left, left), plot.top, width, height),
      const Radius.circular(Sizes.radiusSmall),
    );
    canvas
      ..drawRRect(box, Paint()..color = tooltip)
      ..drawRRect(
        box,
        Paint()
          ..color = baseline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    var y = box.top + pad;
    heading.paint(canvas, Offset(box.left + pad, y));
    y += heading.height + gap;
    for (final (i, line) in lines.indexed) {
      final middle = y + line.height / 2;
      canvas.drawLine(
        Offset(box.left + pad, middle),
        Offset(box.left + pad + 9, middle),
        Paint()
          ..color = rows[i].$1
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      line.paint(canvas, Offset(box.left + pad + key, y));
      y += line.height + gap;
    }
  }

  /// The smallest step from [steps] (scaled by powers of ten) that spans
  /// [range] in at most [count] ticks.
  static double _step(double range, int count, List<double> steps) {
    final rough = range / count;
    var power = 1.0;
    while (power * steps.last < rough) {
      power *= 10;
    }
    while (power > 1e-6 && power * steps.first / 10 >= rough) {
      power /= 10;
    }
    for (final step in steps) {
      if (step * power >= rough) return step * power;
    }
    return steps.last * power;
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  static String _seconds(double value, {bool precise = false}) {
    if (value < 60) {
      return '${precise ? value.toStringAsFixed(1) : _number(value)} s';
    }
    final whole = value.round();
    return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(SpeedChartPainter old) =>
      old._samples != _samples ||
      old.pointer != pointer ||
      old.shown.length != shown.length ||
      !old.shown.every(shown.contains) ||
      old.colors[Delegate.cpu] != colors[Delegate.cpu] ||
      old.ink != ink;
}

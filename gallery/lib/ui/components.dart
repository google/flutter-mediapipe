import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'design.dart';

/// Small uppercase label, as the design sets section names.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: eyebrowStyle(context));
}

/// A page's title.
class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final phone = MediaQuery.sizeOf(context).width < Sizes.compact;
    return Text(
      title,
      style: TextStyle(
        color: c.text,
        fontSize: phone ? 25 : Sizes.xl,
        letterSpacing: (phone ? 25 : Sizes.xl) * -0.04,
        fontWeight: FontWeight.w400,
        height: 1.15,
      ),
    );
  }
}

/// The design's outlined button: Help, and the top bar's icons.
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.icon,
    this.label,
    required this.tooltip,
    required this.onPressed,
    this.bordered = true,
    this.fontSize = Sizes.md,
  });

  final IconData icon;
  final String? label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool bordered;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        container: true,
        button: true,
        // Without a handler the button is disabled, as Stats' switch is while
        // the task restarts.
        enabled: onPressed == null ? false : null,
        label: label == null ? tooltip : null,
        child: Opacity(
          opacity: onPressed == null ? .45 : 1,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Sizes.radiusSmall),
              side: bordered ? BorderSide(color: c.line) : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: c.muted),
                    if (label case final label?) ...[
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: TextStyle(color: c.muted, fontSize: fontSize),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice of a [Segmented] control.
typedef Segment<T> = ({T value, String label, IconData? icon, Key? key});

/// The design's segmented control: the mode switch under a task's heading,
/// and Model and Delegate in the settings. [expand] stretches the segments
/// to the full width, as settings do.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    this.semanticsIdentifier,
  });

  final List<Segment<T>> segments;
  final T? selected;
  final ValueChanged<T>? onChanged;
  final bool expand;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    Widget item(Segment<T> segment) {
      final on = segment.value == selected;
      final enabled = onChanged != null;
      final child = Semantics(
        key: segment.key,
        container: true,
        button: true,
        selected: on,
        enabled: enabled,
        label: segment.label,
        onTap: enabled ? () => onChanged!(segment.value) : null,
        excludeSemantics: true,
        child: Material(
          color: on ? c.surface2 : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: on ? BorderSide(color: c.line) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => onChanged!(segment.value) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (segment.icon case final icon? when !expand) ...[
                    Icon(icon, size: 14, color: on ? c.text : c.muted),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      segment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: on ? c.text : c.muted,
                        fontSize: Sizes.sm,
                      ),
                    ),
                  ),
                  if (segment.icon case final icon? when expand) ...[
                    const SizedBox(width: 7),
                    Icon(icon, size: 13, color: on ? c.text : c.muted),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    Widget control = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: expand ? c.bg : c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final (i, segment) in segments.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            item(segment),
          ],
        ],
      ),
    );
    if (semanticsIdentifier case final id?) {
      control = Semantics(identifier: id, container: true, child: control);
    }
    return control;
  }
}

/// A small round status light.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: color ?? GalleryColors.of(context).teal,
      shape: BoxShape.circle,
    ),
  );
}

/// CPU, GPU or Experimental, as a card's small outlined tag.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: accent ? c.tealLine : c.line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ? c.teal : c.muted,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}

/// One line of an Output card: a name, its score and a bar.
typedef Score = ({String name, double value});

class ScoreBars extends StatelessWidget {
  const ScoreBars(this.items, {super.key, this.digits = 2});

  final List<Score> items;
  final int digits;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return Column(
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(height: 15),
          // Read as one line, "positive 0.98".
          Semantics(
            container: true,
            label: '${item.name} ${item.value.toStringAsFixed(digits)}',
            excludeSemantics: true,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.text, fontSize: Sizes.sm),
                      ),
                    ),
                    Text(
                      item.value.toStringAsFixed(digits),
                      style: TextStyle(
                        color: c.teal,
                        fontSize: Sizes.sm,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: c.tealDim),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: item.value.clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.teal,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A bordered surface card, as the design draws Output and inputs.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final phone = MediaQuery.sizeOf(context).width < Sizes.compact;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(phone ? 17 : 22),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(Sizes.radius),
      ),
      child: child,
    );
  }
}

/// A task's button, then a spinner while the task runs or how long its last
/// run took.
class TaskRunRow extends StatelessWidget {
  const TaskRunRow({
    super.key,
    required this.button,
    required this.busy,
    this.milliseconds,
  });

  final Widget button;
  final bool busy;
  final double? milliseconds;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      button,
      const SizedBox(width: 16),
      if (busy)
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      else if (milliseconds case final ms?)
        Text(
          'Done in ${ms.toStringAsFixed(1)} ms',
          style: TextStyle(
            color: GalleryColors.of(context).muted,
            fontSize: Sizes.xs,
          ),
        ),
    ],
  );
}

/// What went wrong, in an output card.
class TaskErrorCard extends StatelessWidget {
  const TaskErrorCard(this.error, {super.key});

  final Object error;

  @override
  Widget build(BuildContext context) => OutputCard(
    title: 'Error',
    child: Text(
      '$error',
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: Sizes.sm,
      ),
    ),
  );
}

/// The Output card: what the task returned, as score bars or [child].
class OutputCard extends StatelessWidget {
  const OutputCard({
    super.key,
    required this.title,
    this.count,
    this.items = const [],
    this.empty,
    this.child,
    this.onClose,
  });

  final String title;
  final String? count;
  final List<Score> items;

  /// Shown when there are no [items] and no [child].
  final String? empty;
  final Widget? child;

  /// Closes the dialog that shows this card on phones.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Output'),
                    const SizedBox(height: 7),
                    Text(title, style: TextStyle(color: c.text, fontSize: 16)),
                  ],
                ),
              ),
              if (count case final count?)
                Text(
                  count,
                  style: TextStyle(color: c.muted, fontSize: Sizes.sm),
                ),
              if (onClose case final close?) ...[
                const SizedBox(width: 10),
                OutlineButton(
                  icon: LucideIcons.x,
                  tooltip: 'Close output',
                  onPressed: close,
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          if (child case final child?)
            child
          else if (items.isNotEmpty)
            ScoreBars(items)
          else
            Text(
              empty ?? 'Nothing yet.',
              style: TextStyle(color: c.muted, fontSize: Sizes.sm),
            ),
        ],
      ),
    );
  }
}

/// The dark frame, 16:9 unless told otherwise, that holds a camera feed or
/// an image. The child fills it and centers its own picture.
class FeedFrame extends StatelessWidget {
  const FeedFrame({
    super.key,
    required this.child,
    this.aspectRatio = 16 / 9,
    this.maxHeight,
  });

  final Widget child;
  final double aspectRatio;

  /// The tallest the frame grows; a taller [aspectRatio] leaves bars beside
  /// the picture instead.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final phone = MediaQuery.sizeOf(context).width < Sizes.compact;
    final frame = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF090B0B),
        border: phone
            ? Border.symmetric(horizontal: BorderSide(color: c.line))
            : Border.all(color: c.line),
        borderRadius: phone ? null : BorderRadius.circular(Sizes.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    // Phones run the feed edge to edge past the page's 16 px gutters, as the
    // design does. Every width keeps this wrapper, so crossing the phone
    // breakpoint relays out the feed instead of rebuilding its camera view.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth + (phone ? 32 : 0);
        return SizedBox(
          height: math.min(width / aspectRatio, maxHeight ?? double.infinity),
          child: OverflowBox(minWidth: width, maxWidth: width, child: frame),
        );
      },
    );
  }
}

/// A translucent square icon button over the feed.
class FeedButton extends StatelessWidget {
  const FeedButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? const Color(0x66F0F3F2)
        : const Color(0xFFF0F3F2);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xCC101314),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.radiusSmall),
          side: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

/// The line under the feed: frame rate, inference time and delegate.
class FeedStatus extends StatelessWidget {
  const FeedStatus({
    super.key,
    required this.parts,
    this.delegate,
    this.trailing,
  });

  final List<String> parts;
  final String? delegate;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final style = TextStyle(color: c.muted, fontSize: Sizes.xs);
    // Read as one line, "20.1 fps · 5 ms · GPU".
    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            label: [...parts, ?delegate].join(' · '),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final part in parts) Text(part, style: style),
                  if (delegate case final delegate?) ...[
                    Text(delegate, style: style.copyWith(color: c.teal)),
                    const StatusDot(),
                  ],
                ],
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The empty still image frame: a dashed outline and a Choose image button.
class StillCard extends StatelessWidget {
  const StillCard({
    super.key,
    required this.onChoose,
    this.message,
    this.error = false,
  });

  final VoidCallback onChoose;
  final String? message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CustomPaint(
        painter: _DashedBorder(c.hoverLine),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Scales down in a short frame rather than overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.upload, size: 28, color: c.teal),
                  const SizedBox(height: 14),
                  Text(
                    'Choose an image to analyze.',
                    style: TextStyle(
                      color: c.text,
                      fontSize: Sizes.md,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ?? 'JPEG, PNG or WebP from your device',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: error
                          ? Theme.of(context).colorScheme.error
                          : c.muted,
                      fontSize: Sizes.sm,
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(label: 'Choose image', onPressed: onChoose),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Sizes.radius),
        ).deflate(0.5),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 4, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}

/// The design's teal button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final enabled = onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: enabled ? c.teal : c.teal.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(Sizes.radiusSmall),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final icon?) ...[
                  Icon(icon, size: 15, color: c.onTeal),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: c.onTeal,
                    fontWeight: FontWeight.w700,
                    fontSize: Sizes.md,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's on/off switch.
class DesignSwitch extends StatelessWidget {
  const DesignSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return Semantics(
      container: true,
      toggled: value,
      enabled: onChanged != null,
      label: label,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 18,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? c.tealDim : c.switchOff,
            borderRadius: BorderRadius.circular(99),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: value ? c.teal : c.knobOff,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's − n + stepper.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    Widget button(String text, String tooltip, VoidCallback? onTap) => Tooltip(
      message: tooltip,
      child: Semantics(
        container: true,
        button: true,
        enabled: onTap != null,
        label: tooltip,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: c.surface2,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: onTap == null ? c.line : c.muted,
                    fontSize: Sizes.sm,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('−', 'Fewer', onDecrease),
          SizedBox(
            width: 25,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.text, fontSize: Sizes.xs),
            ),
          ),
          button('+', 'More', onIncrease),
        ],
      ),
    );
  }
}

/// A select box, as the design's settings draw one: a bordered field that
/// opens a menu of [options].
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.label,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;

  /// Read before the value by screen readers, such as "Output Type".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Semantics(
        label: label,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            isDense: true,
            padding: const EdgeInsets.symmetric(vertical: 9),
            value: value,
            icon: Icon(LucideIcons.chevronDown, size: 15, color: c.muted),
            dropdownColor: c.surface2,
            borderRadius: BorderRadius.circular(8),
            style: TextStyle(color: c.text, fontSize: Sizes.sm),
            items: [
              for (final (option, text) in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(text, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged == null ? null : (v) => onChanged!(v as T),
          ),
        ),
      ),
    );
  }
}

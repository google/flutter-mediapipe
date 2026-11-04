import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../ui/components.dart';
import '../ui/design.dart';
import 'task_models.dart';
import 'task_settings.dart';

/// A task's model, delegate and settings, in the design's settings panel.
///
/// Sliders report a value once the drag ends, so a task is rebuilt once per
/// change rather than once per pixel dragged; display settings apply while
/// dragged, since they only redraw.
class TaskSettingsPanel extends StatefulWidget {
  const TaskSettingsPanel({
    super.key,
    required this.settings,
    required this.values,
    required this.delegates,
    required this.delegate,
    required this.enabled,
    required this.onChanged,
    required this.onDelegate,
    required this.models,
    required this.model,
    required this.uploaded,
    required this.modelStatus,
    required this.onModel,
    required this.onUpload,
    this.bundledModel,
    this.standardModel = 'Standard',
    this.labels = const [],
  });

  /// The bundled model's file, shown under the model choice.
  final String? bundledModel;

  /// The bundled model's name in the model list.
  final String standardModel;

  /// The running model's labels, which a [LabelSetting] chooses from.
  final List<String> labels;

  /// Google's other official models for the task.
  final List<TaskModel> models;

  /// The chosen official model, or null for the standard or uploaded one.
  final TaskModel? model;

  /// The uploaded file's name while an upload is chosen.
  final String? uploaded;

  /// A download in progress or a model that failed to load.
  final String? modelStatus;
  final void Function(TaskModel? model) onModel;

  /// Null where the task takes no other model.
  final VoidCallback? onUpload;

  final List<TaskSetting> settings;
  final TaskSettingValues values;
  final List<Delegate> delegates;
  final Delegate delegate;

  /// False while the task is being rebuilt.
  final bool enabled;
  final void Function(String key, Object value) onChanged;
  final void Function(Delegate delegate) onDelegate;

  @override
  State<TaskSettingsPanel> createState() => _TaskSettingsPanelState();
}

class _TaskSettingsPanelState extends State<TaskSettingsPanel> {
  /// A slider's position while it is being dragged, before it applies.
  final _dragging = <String, double>{};

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final muted = TextStyle(color: c.muted, fontSize: Sizes.sm);
    final enabled = widget.enabled;
    final model = widget.model;
    final file =
        widget.uploaded ??
        (model == null
            ? widget.bundledModel
            : '${model.name} · ${(model.bytes / 1e6).toStringAsFixed(1)} MB');
    final shownSettings = [
      for (final setting in widget.settings)
        if (_shown(setting)) setting,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          label: 'Model',
          divider: false,
          children: [
            Segmented<bool>(
              expand: true,
              segments: [
                (value: false, label: 'Standard', icon: null, key: null),
                if (widget.onUpload != null)
                  (
                    value: true,
                    label: 'Upload',
                    icon: LucideIcons.upload,
                    key: const ValueKey('model-upload'),
                  ),
              ],
              selected: widget.uploaded != null,
              onChanged: !enabled
                  ? null
                  : (upload) {
                      if (upload) {
                        widget.onUpload?.call();
                      } else if (widget.uploaded != null) {
                        widget.onModel(null);
                      }
                    },
            ),
            if (widget.models.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectField<TaskModel?>(
                key: const ValueKey('model-select'),
                label: 'Model',
                value: widget.uploaded == null ? model : null,
                options: [
                  (null, widget.standardModel),
                  for (final m in widget.models)
                    (m, '${m.name} · ${(m.bytes / 1e6).toStringAsFixed(1)} MB'),
                ],
                onChanged: enabled ? widget.onModel : null,
              ),
            ],
            if (file != null) ...[
              const SizedBox(height: 12),
              Text(file, style: muted),
            ],
            if (widget.modelStatus case final status?) ...[
              const SizedBox(height: 8),
              Text(status, style: muted),
            ],
          ],
        ),
        _Section(
          label: 'Delegate',
          children: [
            Segmented<Delegate>(
              expand: true,
              segments: [
                for (final delegate in widget.delegates)
                  (
                    value: delegate,
                    label: delegate == Delegate.gpu ? 'GPU' : 'CPU',
                    icon: null,
                    key: ValueKey('delegate-${delegate.name}'),
                  ),
              ],
              selected: widget.delegate,
              onChanged: enabled && widget.delegates.length > 1
                  ? widget.onDelegate
                  : null,
            ),
          ],
        ),
        if (shownSettings.isNotEmpty)
          _Section(
            label: 'Task settings',
            children: [
              for (final (i, setting) in shownSettings.indexed) ...[
                if (i > 0) const SizedBox(height: 19),
                _row(setting),
              ],
            ],
          ),
      ],
    );
  }

  /// A [LabelSetting] shows once the model's labels are known, and only for
  /// the choice it belongs to.
  bool _shown(TaskSetting setting) => switch (setting) {
    LabelSetting(:final whenKey, :final whenValue) =>
      widget.labels.isNotEmpty && widget.values[whenKey] == whenValue,
    _ => true,
  };

  /// Display settings redraw only, so a slider may apply while dragged.
  void _slide(ShareSetting setting, double value) {
    setState(() => _dragging[setting.key] = value);
    if (setting.display) {
      widget.onChanged(setting.key, (value * 20).round() / 20);
    }
  }

  Widget _row(TaskSetting setting) {
    final c = GalleryColors.of(context);
    final enabled = widget.enabled || setting.display;
    Widget line(Widget trailing) => Row(
      children: [
        Expanded(
          child: Text(
            setting.label,
            style: TextStyle(color: c.soft, fontSize: Sizes.sm),
          ),
        ),
        const SizedBox(width: 10),
        trailing,
      ],
    );
    return switch (setting) {
      CountSetting(:final min, :final max) => line(
        CountStepper(
          key: ValueKey('setting-${setting.key}'),
          value: widget.values.count(setting.key),
          onDecrease: enabled && widget.values.count(setting.key) > min
              ? () => widget.onChanged(
                  setting.key,
                  widget.values.count(setting.key) - 1,
                )
              : null,
          onIncrease: enabled && widget.values.count(setting.key) < max
              ? () => widget.onChanged(
                  setting.key,
                  widget.values.count(setting.key) + 1,
                )
              : null,
        ),
      ),
      ShareSetting() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(
            Text(
              (_dragging[setting.key] ?? widget.values.share(setting.key))
                  .toStringAsFixed(2),
              style: TextStyle(
                color: c.teal,
                fontSize: Sizes.xs,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Flutter 3.47's Slider keeps its value-bubble overlay entry shown
          // at all times. In the page's overlay, each entry becomes a
          // page-sized web semantics node that swallows every click, so each
          // slider gets an overlay of its own. The value is printed above.
          SizedBox(
            height: 28,
            child: Overlay.wrap(
              alwaysSizeToContent: true,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  overlayShape: SliderComponentShape.noOverlay,
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: Slider(
                  key: ValueKey('setting-${setting.key}'),
                  semanticFormatterCallback: (value) =>
                      '${setting.label} ${value.toStringAsFixed(2)}',
                  value:
                      _dragging[setting.key] ??
                      widget.values.share(setting.key),
                  divisions: 20,
                  onChanged: enabled ? (value) => _slide(setting, value) : null,
                  onChangeEnd: enabled
                      ? (value) {
                          setState(() => _dragging.remove(setting.key));
                          // Twentieths, so 0.35 is not applied as
                          // 0.35000000000000003.
                          widget.onChanged(
                            setting.key,
                            (value * 20).round() / 20,
                          );
                        }
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      SwitchSetting() => line(
        DesignSwitch(
          key: ValueKey('setting-${setting.key}'),
          label: setting.label,
          value: widget.values.on(setting.key),
          onChanged: enabled
              ? (value) => widget.onChanged(setting.key, value)
              : null,
        ),
      ),
      ChoiceSetting(:final options) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(const SizedBox.shrink()),
          const SizedBox(height: 8),
          SelectField<int>(
            key: ValueKey('setting-${setting.key}'),
            label: setting.label,
            value: widget.values.choice(setting.key),
            options: [for (final (i, option) in options.indexed) (i, option)],
            onChanged: enabled
                ? (value) => widget.onChanged(setting.key, value)
                : null,
          ),
        ],
      ),
      LabelSetting() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(const SizedBox.shrink()),
          const SizedBox(height: 8),
          SelectField<int>(
            key: ValueKey('setting-${setting.key}'),
            label: setting.label,
            value: widget.values.choice(setting.key) < widget.labels.length
                ? widget.values.choice(setting.key)
                : 0,
            options: [
              for (final (i, label) in widget.labels.indexed) (i, label),
            ],
            onChanged: (value) => widget.onChanged(setting.key, value),
          ),
        ],
      ),
    };
  }
}

/// One settings section: a rule, its label and its controls.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.children,
    this.divider = true,
  });

  final String label;
  final List<Widget> children;

  /// A line above the section; the first one has nothing above it to part.
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(
      border: divider
          ? Border(top: BorderSide(color: GalleryColors.of(context).line))
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Eyebrow(label), const SizedBox(height: 12), ...children],
    ),
  );
}

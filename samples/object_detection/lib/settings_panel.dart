import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'detector_helper.dart';

/// The panel under the preview, as in Google's Android sample: the inference
/// time, and when expanded the threshold, result limit, delegate and model.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.inferenceMilliseconds,
  });

  final ValueNotifier<DetectorSettings> settings;
  final ValueListenable<int?> inferenceMilliseconds;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _expanded = false;
  Set<Delegate> _supported = const {Delegate.cpu};

  @override
  void initState() {
    super.initState();
    queryObjectDetectorCapabilities().then((capabilities) {
      if (mounted) {
        setState(() => _supported = capabilities.supportedDelegates);
      }
    });
  }

  void _update(DetectorSettings Function(DetectorSettings) change) =>
      widget.settings.value = change(widget.settings.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.settings,
            widget.inferenceMilliseconds,
          ]),
          builder: (context, _) {
            final settings = widget.settings.value;
            final inference = widget.inferenceMilliseconds.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Inference time'),
                  subtitle: Text(inference == null ? '-' : '$inference ms'),
                  trailing: Icon(
                    _expanded ? Icons.expand_more : Icons.expand_less,
                  ),
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
                if (_expanded) ...[
                  _Stepper(
                    label: 'Threshold',
                    value: settings.threshold.toStringAsFixed(2),
                    onMinus: settings.threshold > 0.15
                        ? () => _update(
                            (s) =>
                                s.copyWith(threshold: _step(s.threshold, -1)),
                          )
                        : null,
                    onPlus: settings.threshold < 0.75
                        ? () => _update(
                            (s) => s.copyWith(threshold: _step(s.threshold, 1)),
                          )
                        : null,
                  ),
                  _Stepper(
                    label: 'Max results',
                    value: '${settings.maxResults}',
                    onMinus: settings.maxResults > 1
                        ? () => _update(
                            (s) => s.copyWith(maxResults: s.maxResults - 1),
                          )
                        : null,
                    onPlus: settings.maxResults < 10
                        ? () => _update(
                            (s) => s.copyWith(maxResults: s.maxResults + 1),
                          )
                        : null,
                  ),
                  ListTile(
                    title: const Text('Delegate'),
                    trailing: SegmentedButton<Delegate>(
                      segments: [
                        for (final delegate in Delegate.values)
                          ButtonSegment(
                            value: delegate,
                            label: Text(delegate.name.toUpperCase()),
                            enabled: _supported.contains(delegate),
                          ),
                      ],
                      selected: {settings.delegate},
                      onSelectionChanged: (selected) =>
                          _update((s) => s.copyWith(delegate: selected.single)),
                    ),
                  ),
                  const ListTile(
                    title: Text('ML model'),
                    trailing: Text('EfficientDet-Lite0'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Moves [threshold] a tenth up or down, kept on the tenths.
double _step(double threshold, int tenths) =>
    ((threshold * 10).round() + tenths) / 10;

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Decrease',
          icon: const Icon(Icons.remove),
          onPressed: onMinus,
        ),
        SizedBox(width: 40, child: Text(value, textAlign: TextAlign.center)),
        IconButton(
          tooltip: 'Increase',
          icon: const Icon(Icons.add),
          onPressed: onPlus,
        ),
      ],
    ),
  );
}

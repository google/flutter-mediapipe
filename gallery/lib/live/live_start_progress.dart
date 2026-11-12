import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// How far a camera demo's start has got. The model, runtime and camera load
/// at once; [step] names the first unfinished one.
class LiveStartProgress {
  int _modelReceived = 0;
  int? _modelTotal;
  bool _modelLoaded = false;
  bool _taskOpen = false;
  bool _cameraOpen = false;

  /// Clears it for another start.
  void restart() {
    _modelReceived = 0;
    _modelTotal = null;
    _modelLoaded = false;
    _taskOpen = false;
    _cameraOpen = false;
  }

  /// Records the model's download. Whether [percent] changed, so a page
  /// redraws per whole percent and not per network chunk.
  bool modelReceived(int received, int? total) {
    final before = percent;
    _modelReceived = received;
    _modelTotal = total;
    return percent != before;
  }

  void modelLoaded() => _modelLoaded = true;
  void taskOpen() => _taskOpen = true;
  void cameraOpen() => _cameraOpen = true;

  /// What the start is waiting on.
  String get step {
    if (!_modelLoaded) {
      return _modelTotal == null ? 'Loading model' : 'Downloading model';
    }
    if (!_taskOpen) return 'Starting MediaPipe';
    if (!_cameraOpen) return 'Waiting for camera';
    return 'Warming up';
  }

  /// The model's megabytes received while it downloads, or null.
  String? get detail {
    final total = _modelTotal;
    if (_modelLoaded || total == null) return null;
    String megabytes(int bytes) => (bytes / 1000000).toStringAsFixed(1);
    return '${megabytes(_modelReceived)} / ${megabytes(total)} MB';
  }

  /// The start's progress from 0 to 1, or null while it cannot be measured: an
  /// uploaded or alternative model reports no size. The download is most of
  /// the wait, so it fills the first 80%.
  double? get value {
    if (!_modelLoaded) {
      final total = _modelTotal;
      if (total == null || total == 0) return null;
      return .8 * math.min(_modelReceived / total, 1);
    }
    if (!_taskOpen) return .8;
    if (!_cameraOpen) return .9;
    return .95;
  }

  /// [value] as a whole percent, or null.
  int? get percent => switch (value) {
    final value? => (value * 100).round(),
    null => null,
  };

  /// One line for a status bar.
  String get summary =>
      [step, if (percent case final percent?) '$percent%'].join(' ');
}

/// [progress] on the feed while a camera demo starts.
class LiveStartCard extends StatelessWidget {
  const LiveStartCard(this.progress, {super.key});
  final LiveStartProgress progress;

  @override
  Widget build(BuildContext context) {
    const text = Color(0xFFF0F3F2);
    final detail = progress.detail;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD202124),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${progress.step}...',
                      style: const TextStyle(color: text),
                    ),
                  ),
                  if (progress.percent case final percent?)
                    Text('$percent%', style: const TextStyle(color: text)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.value,
                  minHeight: 4,
                  backgroundColor: text.withValues(alpha: .2),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: TextStyle(
                    color: text.withValues(alpha: .7),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../live/camera_geometry.dart';
import '../live/live_subjects.dart';
import 'live_camera_controller.dart';
import 'overlay_toggle.dart';
import 'test_hooks.dart';

/// Preview and Flutter landmarks use identical intrinsic dimensions and mirroring.
class LiveCameraView extends StatelessWidget {
  const LiveCameraView({
    super.key,
    required this.controller,
    required this.painter,
    required this.placeholder,
    required this.showConnections,
    required this.showPoints,
  });
  final LiveCameraController<Object?> controller;
  final CustomPainter? Function(PreviewTransform transform) painter;
  final Widget placeholder;
  final bool showConnections;
  final bool showPoints;
  @override
  Widget build(BuildContext context) {
    installOverlayToggle();
    final frame = controller.frameSize;
    // Keep the video attached while a running task changes delegate/device.
    // Removing its platform view during stream replacement can prevent Chrome
    // from delivering requestVideoFrameCallback on the restarted stream.
    if (frame == null) return Center(child: placeholder);
    // While a drawer or sheet covers the feed, Flutter draws the paused frame
    // and the platform views stay mounted but out of the scene, so the page
    // renders as one canvas; see LiveCameraController.previewHidden.
    final hidden = controller.previewHidden;
    final paused = controller.pausedFrame;
    return Center(
      child: AspectRatio(
        aspectRatio: frame.width / frame.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: hidden,
              child: HtmlElementView.fromTagName(
                tagName: 'div',
                onElementCreated: (element) {
                  // The video is owned by the controller and reused across restarts.
                  final container = element as web.HTMLElement;
                  container.style
                    ..width = '100%'
                    ..height = '100%'
                    ..position = 'relative'
                    ..pointerEvents = 'none';
                  controller.video.style
                    ..position = 'absolute'
                    ..left = '0'
                    ..top = '0';
                  container.append(controller.video);
                  if (controller.useCanvasPreview) {
                    controller.previewCanvas.style
                      ..position = 'absolute'
                      ..left = '0'
                      ..top = '0'
                      ..width = '100%'
                      ..height = '100%'
                      ..pointerEvents = 'none';
                    container.append(controller.previewCanvas);
                  }
                },
              ),
            ),
            // Stays after the platform view, so that view keeps its element.
            if (hidden && paused != null)
              Transform.flip(
                flipX: controller.isFrontCamera,
                child: RawImage(image: paused, fit: BoxFit.fill),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final transform = PreviewTransform.fit(
                  frameSize: frame,
                  rotationDegrees: 0,
                  viewSize: constraints.biggest,
                  mirror: controller.isFrontCamera,
                );
                controller.setOverlayOptions(
                  connections: showConnections,
                  points: showPoints,
                  scale: transform.scale,
                );
                if (testHooks) _publishProbes(context, transform);
                if (controller.workerOverlayCanvas case final canvas?) {
                  final overlay = hidden ? painter(transform) : null;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Offstage(
                        offstage: hidden,
                        child: HtmlElementView.fromTagName(
                          key: ValueKey(canvas),
                          tagName: 'div',
                          onElementCreated: (element) {
                            final container = element as web.HTMLElement;
                            container.style
                              ..width = '100%'
                              ..height = '100%'
                              ..pointerEvents = 'none';
                            container.append(canvas);
                          },
                        ),
                      ),
                      // The worker's drawing is out of the scene with it.
                      if (overlay != null) CustomPaint(painter: overlay),
                    ],
                  );
                }
                final overlay = painter(transform);
                return overlay == null
                    ? const SizedBox.shrink()
                    : CustomPaint(painter: overlay);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Records on the video element where the overlay draws the first
  /// subject's [AlignmentProbes], and their mirror partners, for the browser
  /// suite's alignment oracle (`tool/browser/test_browser.mjs`).
  ///
  /// Uses the painter's own [transform] and reads the overlay's place on the
  /// page after layout; logical pixels are CSS pixels on web. The probes and
  /// the fitted frame are relative to that overlay box.
  void _publishProbes(BuildContext context, PreviewTransform transform) {
    final video = controller.video;
    final result = controller.result;
    final probed = AlignmentProbes.of(result);
    final subjects = liveSubjects(result);
    if (probed == null || subjects.isEmpty) {
      video
        ..removeAttribute('data-probes')
        ..removeAttribute('data-partners');
      return;
    }
    final subject = subjects.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.mounted ? context.findRenderObject() : null;
      if (box is! RenderBox || !box.hasSize) return;
      final origin = box.localToGlobal(Offset.zero);
      final fitted = transform.uprightSize * transform.scale;
      final probes = <String, List<double>>{};
      for (final index in probed.indices) {
        final point = transform.map(subject[index].x, subject[index].y);
        probes['$index'] = [point.dx, point.dy];
      }
      video
        ..setAttribute(
          'data-overlay-box',
          jsonEncode([origin.dx, origin.dy, box.size.width, box.size.height]),
        )
        ..setAttribute(
          'data-frame-box',
          jsonEncode([
            transform.offsetX,
            transform.offsetY,
            fitted.width,
            fitted.height,
          ]),
        )
        ..setAttribute('data-mirror', '${transform.mirror}')
        ..setAttribute('data-rotation', '${transform.quarterTurns * 90}')
        ..setAttribute('data-probes', jsonEncode(probes))
        ..setAttribute(
          'data-partners',
          jsonEncode(
            probed.partners.map(
              (index, partner) => MapEntry('$index', partner),
            ),
          ),
        );
    });
  }
}

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'camera_geometry.dart';
import 'live_camera_controller.dart';

/// The preview and its overlay, laid out so the two agree.
///
/// Every live tile draws through this, so rotation, aspect ratio and front
/// camera mirroring are settled once rather than per demo. The tile supplies
/// only a painter, built from the [PreviewTransform] that maps MediaPipe's
/// coordinates onto the pixels the viewer is looking at.
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

  /// Builds the overlay for the current result, or null to draw nothing.
  final CustomPainter? Function(PreviewTransform transform) painter;

  /// Shown until the camera is live.
  final Widget placeholder;
  final bool showConnections;
  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    final camera = controller.camera;
    if (camera == null || !camera.value.isInitialized) {
      return Center(child: placeholder);
    }
    // Match the box to what CameraPreview does internally: it inverts the
    // sensor's landscape ratio when the device is portrait. Laying the parent
    // out any other way letterboxes the preview inside its own parent and the
    // overlay stops lining up.
    final orientation = camera.value.deviceOrientation;
    return Center(
      child: AspectRatio(
        aspectRatio: previewAspectRatio(camera.value.aspectRatio, orientation),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(camera),
            LayoutBuilder(
              builder: (context, constraints) {
                final frame = controller.frameSize;
                if (frame == null) return const SizedBox.shrink();
                final overlay = painter(
                  PreviewTransform.fit(
                    frameSize: frame,
                    rotationDegrees: controller.frameRotationDegrees,
                    viewSize: constraints.biggest,
                    mirror: previewIsMirrored(
                      isFrontCamera: controller.isFrontCamera,
                    ),
                  ),
                );
                if (overlay == null) return const SizedBox.shrink();
                return CustomPaint(painter: overlay);
              },
            ),
          ],
        ),
      ),
    );
  }
}

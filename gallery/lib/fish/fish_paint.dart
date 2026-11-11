import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'fish_game.dart';

/// Draws [fish] in world units, its parts sized by [Fish]'s shape, which
/// [fishTouch] decides collisions from.
void paintFish(Canvas canvas, Fish fish, Color color) {
  final direction = fish.facingLeft ? -1.0 : 1.0;
  final body = Rect.fromCenter(
    center: Offset(fish.x, fish.y),
    width: fish.size * Fish.bodyHalfLength * 2,
    height: fish.size * Fish.bodyHalfHeight * 2,
  );
  final [start, top, bottom] = fish.tailPoints;
  final tail = Path()
    ..moveTo(start.$1, start.$2)
    ..lineTo(top.$1, top.$2)
    ..lineTo(bottom.$1, bottom.$2)
    ..close();
  final paint = Paint()..color = color;
  canvas
    ..drawPath(tail, paint)
    ..drawOval(body, paint);
  if (fish.outline > 0) {
    canvas.drawOval(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = fish.outline,
    );
  }
  canvas
    ..drawCircle(
      Offset(fish.x + direction * fish.size * 0.6, fish.y - fish.size * 0.2),
      math.max(1.5, fish.size * 0.16),
      Paint()..color = Colors.white,
    )
    ..drawCircle(
      Offset(fish.x + direction * fish.size * 0.65, fish.y - fish.size * 0.2),
      math.max(0.8, fish.size * 0.08),
      Paint()..color = Colors.black,
    );
}

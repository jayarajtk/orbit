import 'package:flutter/material.dart';
import 'package:orbit/features/status/domain/status.dart';

/// Draws the status ring of [ring] over the edge of [child], inset so it
/// stays inside the child's bounds. Unseen is an accent gradient, seen is
/// muted, none draws nothing.
class StatusRingFrame extends StatelessWidget {
  /// Creates a frame. A null [radius] makes the ring a circle (for a round
  /// avatar); pass the tile's radius for a rounded tile.
  const StatusRingFrame({
    required this.ring,
    required this.child,
    this.width = 2.5,
    this.radius,
    super.key,
  });

  /// Which ring to draw.
  final StatusRing ring;

  /// What the ring surrounds.
  final Widget child;

  /// Stroke width.
  final double width;

  /// Corner radius of a tile; null for a circle.
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    if (ring == StatusRing.none) return child;
    final scheme = Theme.of(context).colorScheme;
    final colors = ring == StatusRing.unseen
        ? [scheme.primary, const Color(0xFFFF9F0A)] // ring-gradient
        : [scheme.onSurfaceVariant.withValues(alpha: 0.5)];
    return CustomPaint(
      foregroundPainter: StatusRingPainter(
        colors: colors,
        width: width,
        radius: radius,
      ),
      child: child,
    );
  }
}

/// Strokes a ring, as a gradient when it has two or more [colors].
class StatusRingPainter extends CustomPainter {
  /// Creates a painter.
  const StatusRingPainter({
    required this.colors,
    required this.width,
    this.radius,
  });

  /// One colour, or the gradient's start and end.
  final List<Color> colors;

  /// Stroke width.
  final double width;

  /// Corner radius; null for a circle.
  final BorderRadius? radius;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..isAntiAlias = true;
    if (colors.length > 1) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(bounds);
    } else {
      paint.color = colors.first;
    }
    final corners = radius;
    canvas.drawRRect(
      corners == null
          ? RRect.fromRectAndRadius(
              bounds,
              Radius.circular(bounds.shortestSide / 2),
            )
          : corners.toRRect(bounds),
      paint,
    );
  }

  @override
  bool shouldRepaint(StatusRingPainter old) =>
      old.width != width ||
      old.radius != radius ||
      !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
}

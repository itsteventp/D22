import 'package:flutter/material.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// VoidBackgroundPainter — dot grid for the "infinite void" canvas aesthetic
// ---------------------------------------------------------------------------
class VoidBackgroundPainter extends CustomPainter {
  final Offset offset; // unused for static canvas, kept for future panning

  const VoidBackgroundPainter({this.offset = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    // Radial gradient background — slightly lighter at center
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        const Color(0xFF14141A),
        AppColors.background,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Dot grid
    final dotPaint = Paint()
      ..color = const Color(0xFF2A2A38).withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const gridSpacing = 52.0;
    const dotRadius = 0.85;

    final startX = offset.dx % gridSpacing;
    final startY = offset.dy % gridSpacing;

    for (double x = startX; x < size.width + gridSpacing; x += gridSpacing) {
      for (double y = startY; y < size.height + gridSpacing; y += gridSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(VoidBackgroundPainter oldDelegate) =>
      oldDelegate.offset != offset;
}

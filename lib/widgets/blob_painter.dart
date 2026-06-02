import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../map_node.dart';
import '../map_physics.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// BlobCanvasPainter — renders connections + blobs on the void canvas
// ---------------------------------------------------------------------------
class BlobCanvasPainter extends CustomPainter {
  final List<MapNode> nodes;
  final List<MapConnection> connections;
  final BlobPhysicsSimulator physics;
  final String? hoveredNodeId;
  final String? draggedNodeId;

  const BlobCanvasPainter({
    required this.nodes,
    required this.connections,
    required this.physics,
    this.hoveredNodeId,
    this.draggedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawConnections(canvas);
    _drawBlobs(canvas);
  }

  // ---------------------------------------------------------------------------
  // Connection lines — glowing gradient strokes between blob centers
  // ---------------------------------------------------------------------------
  void _drawConnections(Canvas canvas) {
    for (final conn in connections) {
      final fromPhys = physics.get(conn.fromId);
      final toPhys   = physics.get(conn.toId);
      if (fromPhys == null || toPhys == null) continue;

      final fromNode = nodes.firstWhere((n) => n.id == conn.fromId, orElse: () => nodes.first);
      final toNode   = nodes.firstWhere((n) => n.id == conn.toId,   orElse: () => nodes.first);

      final fromPos = fromPhys.position;
      final toPos   = toPhys.position;

      // Gradient line from concept color to concept color
      final shader = ui.Gradient.linear(
        fromPos,
        toPos,
        [
          fromNode.color.withValues(alpha: 0.35),
          toNode.color.withValues(alpha: 0.35),
        ],
      );

      final linePaint = Paint()
        ..shader = shader
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(fromPos, toPos, linePaint);

      // Glow layer — wider, very transparent
      final glowPaint = Paint()
        ..color = fromNode.color.withValues(alpha: 0.07)
        ..strokeWidth = 12.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawLine(fromPos, toPos, glowPaint);
    }
  }

  // ---------------------------------------------------------------------------
  // Blobs
  // ---------------------------------------------------------------------------
  void _drawBlobs(Canvas canvas) {
    for (final node in nodes) {
      final phys = physics.get(node.id);
      if (phys == null) continue;

      final pos    = phys.position;
      final r      = phys.radius;
      final scale  = _elasticOut(phys.spawnScale);
      final isHov  = node.id == hoveredNodeId;
      final isDrag = node.id == draggedNodeId;
      final visualScale = (isHov || isDrag) ? 1.08 : 1.0;
      final totalScale  = scale * visualScale;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.scale(totalScale);

      final color = node.color;

      // --- Outer glow ---
      final glowPaint = Paint()
        ..color = color.withValues(alpha: isDrag ? 0.22 : (isHov ? 0.15 : 0.08))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.65);
      canvas.drawCircle(Offset.zero, r, glowPaint);

      // --- Fill ---
      final fillOpacity = isDrag ? 0.28 : (isHov ? 0.20 : 0.12);
      final fillPaint = Paint()
        ..color = color.withValues(alpha: fillOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, r, fillPaint);

      // --- Ring ---
      final ringOpacity = isDrag ? 0.80 : (isHov ? 0.65 : 0.45);
      final ringPaint = Paint()
        ..color = color.withValues(alpha: ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset.zero, r, ringPaint);

      canvas.restore();

      // --- Label below blob (not scaled to keep it readable) ---
      _drawLabel(canvas, node.title, pos, r * scale * visualScale, color, isHov || isDrag);
    }
  }

  // ---------------------------------------------------------------------------
  // Text label painted below the blob circle
  // ---------------------------------------------------------------------------
  void _drawLabel(Canvas canvas, String title, Offset center, double r, Color color, bool active) {
    final labelY = center.dy + r + 10.0;

    final textStyle = ui.TextStyle(
      color: active ? AppColors.textPrimary : AppColors.textSecondary,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );

    final paraBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      maxLines: 1,
    ))
      ..pushStyle(textStyle)
      ..addText(title);

    final para = paraBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 120));

    final labelX = center.dx - para.longestLine / 2;
    canvas.drawParagraph(para, Offset(labelX, labelY));
  }

  // ---------------------------------------------------------------------------
  // Elastic-out easing for spawn scale
  // ---------------------------------------------------------------------------
  double _elasticOut(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    const c4 = (2 * pi) / 3;
    return pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1;
  }

  @override
  bool shouldRepaint(BlobCanvasPainter old) => true; // always repaint (driven by ticker)
}

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../map_node.dart';
import '../map_physics.dart';
import '../theme.dart';
import 'pentagram_painter.dart';

const Map<String, String> kEndingIdToConcept = {
  'item-0bi5zd23': 'c1',
  'item-e5ll33d5': 'c2',
  'item-mdlobj7c': 'c3',
  'item-ixq598xl': 'c4',
  'item-ce8tf850': 'c5',
};

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
    _drawConnections(canvas, size);
    _drawBlobs(canvas);
  }

  Offset? _getEndingPosition(String itemId, Size size) {
    final concept = kEndingIdToConcept[itemId];
    if (concept == null) return null;

    const double inputBarH = 66.0;
    final center = Offset(size.width / 2, (inputBarH + size.height) / 2);
    final radius = (size.shortestSide * 0.19).clamp(65.0, 115.0);

    final index = const ['c1', 'c2', 'c3', 'c4', 'c5'].indexOf(concept);
    if (index == -1) return null;

    return Offset(
      center.dx + cos(-pi / 2 + index * 2 * pi / 5) * radius,
      center.dy + sin(-pi / 2 + index * 2 * pi / 5) * radius,
    );
  }

  // ---------------------------------------------------------------------------
  // Connection lines — glowing gradient strokes between blob centers
  // ---------------------------------------------------------------------------
  void _drawConnections(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    for (final conn in connections) {
      final fromPhys = physics.get(conn.fromId);
      final toPhys   = physics.get(conn.toId);

      final Offset? fromPos = fromPhys?.position ?? _getEndingPosition(conn.fromId, size);
      final Offset? toPos   = toPhys?.position   ?? _getEndingPosition(conn.toId, size);

      if (fromPos == null || toPos == null) continue;

      final fromNode = nodeMap[conn.fromId];
      final fromColor = fromNode != null
          ? fromNode.color
          : kConceptColors[kEndingIdToConcept[conn.fromId]];

      final toNode = nodeMap[conn.toId];
      final toColor = toNode != null
          ? toNode.color
          : kConceptColors[kEndingIdToConcept[conn.toId]];

      if (fromColor == null || toColor == null) continue;

      // Gradient line from concept color to concept color
      final shader = ui.Gradient.linear(
        fromPos,
        toPos,
        [
          fromColor.withValues(alpha: 0.35),
          toColor.withValues(alpha: 0.35),
        ],
      );

      final linePaint = Paint()
        ..shader = shader
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(fromPos, toPos, linePaint);

      // Glow layer — wider, very transparent
      // Performance optimization: Draw hardware-accelerated solid wide stroke with low alpha
      // instead of high-radius blur filter
      final glowPaint = Paint()
        ..color = fromColor.withValues(alpha: 0.03)
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

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
      // Performance optimization: Only compute expensive blur filter for hovered/dragged nodes.
      // Fall back to a standard flat halo for passive nodes.
      if (isHov || isDrag) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: isDrag ? 0.22 : 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.65);
        canvas.drawCircle(Offset.zero, r, glowPaint);
      } else {
        canvas.drawCircle(
          Offset.zero,
          r * 1.5,
          Paint()
            ..color = color.withValues(alpha: 0.03)
            ..style = PaintingStyle.fill,
        );
      }

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
    final labelY = center.dy + r + 6.0;

    final textStyle = ui.TextStyle(
      color: active ? AppColors.textPrimary : AppColors.textSecondary,
      fontSize: 9.0,
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

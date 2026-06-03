import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Public constants — used for hit-testing in map_screen.dart
// ---------------------------------------------------------------------------
const String kCoreNodeId = '_core_';

const Map<String, String> kConceptToolNames = {
  'c1': 'Color',
  'c2': 'Mod 36',
  'c3': 'Balance',
  'c4': 'Adjacent',
  'c5': 'Symmetry',
};

const Map<String, Color> kConceptColors = {
  'c1': AppColors.conceptPurple,
  'c2': AppColors.conceptBlue,
  'c3': AppColors.conceptTeal,
  'c4': AppColors.conceptOrange,
  'c5': AppColors.conceptRose,
};

// ---------------------------------------------------------------------------
// PentagramPainter — draws the fixed 5-vertex pentagram structure:
//   1. A subtle pentagon outline connecting adjacent nodes
//   2. Vertex circles (dormant dark ring → active glowing blob)
//   3. An animated thread drawn from center through unlock order vertices
//   4. The center "Core" node (post-completion, used to navigate to Grid)
// ---------------------------------------------------------------------------
class PentagramPainter extends CustomPainter {
  final Map<String, Offset> conceptPositions;
  final Offset center;
  final Set<String> activeEndings;
  final List<String> unlockOrder;
  final double animProgress; // 0.0 → 1.0 drives thread draw
  final bool showCore;
  final String? hoveredId;  // 'c1'–'c5' or kCoreNodeId
  final double elapsed;     // from physics ticker — drives core pulse
  final int activeToolIndex; // current activeTool (1-5) for active highlight

  final double nodeRadius;  // injected — interpolated during map↔grid transition
  final double coreRadius;

  final bool isGridMode;
  final int unlockedCluesCount;
  final DateTime? startDate;

  // Ordered concept list (clockwise from top, matching pentagram layout)
  static const List<String> _conceptOrder = ['c1', 'c2', 'c3', 'c4', 'c5'];

  const PentagramPainter({
    required this.conceptPositions,
    required this.center,
    required this.activeEndings,
    required this.unlockOrder,
    required this.animProgress,
    required this.showCore,
    this.hoveredId,
    this.elapsed = 0.0,
    this.activeToolIndex = 0,
    this.nodeRadius = 18.0,  // default = map mode size
    this.coreRadius = 12.0,
    this.isGridMode = false,
    this.unlockedCluesCount = 5,
    this.startDate,
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Paint entry
  // ──────────────────────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    _drawPentagonOutline(canvas);
    _drawVertices(canvas);
    if (showCore) {
      _drawThread(canvas);
      _drawCore(canvas);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Subtle pentagon connecting adjacent nodes
  // ──────────────────────────────────────────────────────────────────────────
  void _drawPentagonOutline(Canvas canvas) {
    if (conceptPositions.length < 5) return;

    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.10)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool first = true;
    for (final c in _conceptOrder) {
      final pos = conceptPositions[c];
      if (pos == null) continue;
      if (first) {
        path.moveTo(pos.dx, pos.dy);
        first = false;
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Vertex circles
  // ──────────────────────────────────────────────────────────────────────────
  void _drawVertices(Canvas canvas) {
    const toolMap = {'c1': 1, 'c2': 2, 'c3': 3, 'c4': 4, 'c5': 5};

    for (final concept in _conceptOrder) {
      final pos = conceptPositions[concept];
      if (pos == null) continue;

      final isActive  = activeEndings.contains(concept);
      final isHovered = hoveredId == concept;
      final isToolActive = isActive && toolMap[concept] == activeToolIndex;
      final color = kConceptColors[concept] ?? Colors.grey;

      // Unlocked state computation
      final conceptIndex = unlockOrder.indexOf(concept);
      final isConceptUnlocked = !isGridMode || 
          (conceptIndex != -1 && conceptIndex < unlockedCluesCount);

      // Scale: active tool → 1.07, hovered → 1.10, default → 1.0
      final scale = isHovered ? 1.10 : (isToolActive ? 1.07 : 1.0);
      final r = isConceptUnlocked ? (nodeRadius * scale) : 3.0;

      // Active outer glow
      if (isActive && isConceptUnlocked) {
        canvas.drawCircle(
          pos, r * 2.0,
          Paint()
            ..color = color.withValues(alpha: isToolActive ? 0.16 : 0.09)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
        );
      }

      // Fill
      canvas.drawCircle(
        pos, r,
        Paint()
          ..color = (isActive && isConceptUnlocked)
              ? color.withValues(alpha: isHovered ? 0.28 : (isToolActive ? 0.22 : 0.13))
              : AppColors.background.withValues(alpha: 0.75),
      );

      // Ring
      canvas.drawCircle(
        pos, r,
        Paint()
          ..color = (isActive && isConceptUnlocked)
              ? color.withValues(alpha: isHovered ? 0.95 : (isToolActive ? 0.85 : 0.62))
              : AppColors.textMuted.withValues(alpha: isHovered ? 0.38 : 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isToolActive && isConceptUnlocked) ? 2.2 : ((isActive && isConceptUnlocked) ? 1.5 : 1.0),
      );

      // Countdown timer for the upcoming locked clue
      final isUpcoming = isGridMode && conceptIndex == unlockedCluesCount && startDate != null;
      if (isUpcoming) {
        final nextUnlockTime = startDate!.add(Duration(hours: (unlockedCluesCount + 1) * 24));
        final diff = nextUnlockTime.difference(DateTime.now());

        String remainingText = '';
        if (diff.inHours >= 1) {
          remainingText = '${diff.inHours}h';
        } else if (diff.inMinutes >= 1) {
          remainingText = '${diff.inMinutes}m';
        } else {
          remainingText = '${diff.inSeconds.clamp(0, 59)}s';
        }

        final dir = (pos - center) / (pos - center).distance;
        final indicatorCenter = pos + dir * 16.0;
        final indicatorColor = kConceptColors[concept] ?? AppColors.textMuted;

        _drawClockIcon(canvas, indicatorCenter, indicatorColor.withValues(alpha: 0.75));

        final textPainter = TextPainter(
          text: TextSpan(
            text: remainingText,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.0,
              color: indicatorColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final double textX = dir.dx >= 0
            ? indicatorCenter.dx + 8.0
            : indicatorCenter.dx - 8.0 - textPainter.width;
        final double textY = indicatorCenter.dy - textPainter.height / 2;

        textPainter.paint(canvas, Offset(textX, textY));
      }
    }
  }

  void _drawClockIcon(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 5.0, paint);
    canvas.drawLine(center, center + const Offset(0, -3), paint);
    canvas.drawLine(center, center + const Offset(2.5, 0), paint);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Animated thread — traced from center through unlock order vertices
  // ──────────────────────────────────────────────────────────────────────────
  void _drawThread(Canvas canvas) {
    if (unlockOrder.isEmpty || animProgress <= 0) return;

    final path = Path()..moveTo(center.dx, center.dy);
    for (final concept in unlockOrder) {
      final pos = conceptPositions[concept];
      if (pos != null) path.lineTo(pos.dx, pos.dy);
    }

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final drawLen = metric.length * animProgress.clamp(0.0, 1.0);
    final subPath = metric.extractPath(0, drawLen);

    // Soft glow layer
    canvas.drawPath(
      subPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..strokeWidth = 14.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Main visible line
    canvas.drawPath(
      subPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Core node — pulsing white circle at canvas center
  // ──────────────────────────────────────────────────────────────────────────
  void _drawCore(Canvas canvas) {
    final isHovered = hoveredId == kCoreNodeId;
    final pulse = sin(elapsed * 2.2) * 0.10 + 0.90; // oscillates 0.80–1.0
    final r = coreRadius * (isHovered ? 1.18 : pulse);

    // Distant glow
    canvas.drawCircle(
      center, r * 2.8,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.055 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // Fill
    canvas.drawCircle(
      center, r,
      Paint()..color = Colors.white.withValues(alpha: isHovered ? 0.97 : 0.90),
    );

    // Hover ring accent
    if (isHovered) {
      canvas.drawCircle(
        center, r + 7,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // shouldRepaint — always repaint when core is visible (for pulse), otherwise
  // only on meaningful state changes.
  // ──────────────────────────────────────────────────────────────────────────
  @override
  bool shouldRepaint(PentagramPainter old) {
    if (showCore) return true; // core pulse requires every-frame repaint
    if (old.center != center) return true; // position transition
    if (old.nodeRadius != nodeRadius) return true; // size transition
    return old.activeEndings.length != activeEndings.length ||
        old.animProgress != animProgress ||
        old.hoveredId != hoveredId ||
        old.activeToolIndex != activeToolIndex ||
        old.isGridMode != isGridMode ||
        old.unlockedCluesCount != unlockedCluesCount ||
        old.startDate != startDate;
  }
}

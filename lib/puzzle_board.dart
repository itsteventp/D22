import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'grid_cell.dart';
import 'grid_state.dart';
import 'theme.dart';

class PuzzleBoard extends StatelessWidget {
  const PuzzleBoard({super.key});

  static const double cellWidth   = 120.0;
  static const double cellHeight  = 40.0;
  static const double cellSpacing = 8.0;
  static const double handleSize  = 32.0;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Column(
      children: [
        // ── Header ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 12.0),
          child: Column(
            children: [
              Text(
                'Grid Decryptor',
                style: AppTextStyles.display(),
              ),
              const SizedBox(height: 4.0),
              Selector<GridState, int>(
                selector: (_, s) => s.activeTool,
                builder: (context, activeTool, _) {
                  final label = activeTool == 0
                      ? 'Stabilization Active'
                      : activeTool == 6
                          ? 'Semantic Core Active'
                          : 'Decryptor Tool $activeTool Active';
                  return AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: Text(
                      label.toUpperCase(),
                      key: ValueKey(activeTool),
                      style: AppTextStyles.caption(
                        color: activeTool > 0
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // ── Tool Selector ─────────────────────────────────────────────────
        Selector<GridState, int>(
          selector: (_, s) => s.activeTool,
          builder: (context, activeTool, _) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: _ToolSelector(
                activeTool: activeTool,
                onSelect: state.setActiveTool,
              ),
            );
          },
        ),

        // ── Board ────────────────────────────────────────────────────────
        Expanded(
          child: Center(
            child: Selector<GridState, int>(
              selector: (_, s) => s.activeTool,
              builder: (context, activeTool, _) {
                final double totalWidth = handleSize +
                    6 * (cellWidth + cellSpacing) +
                    (activeTool == 3 ? cellWidth + cellSpacing : 0) +
                    16.0;
                final double totalHeight = handleSize +
                    8 * (cellHeight + cellSpacing) +
                    (activeTool == 2 ? handleSize + cellSpacing : 0) +
                    16.0;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: GestureDetector(
                      onTap: () => state.clearSelection(),
                      child: AnimatedContainer(
                        duration: AppDurations.normal,
                        width: totalWidth,
                        height: totalHeight,
                        margin: const EdgeInsets.all(16.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 32,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // 1. Ghost slot backgrounds
                            ...List.generate(8, (r) {
                              return List.generate(6, (c) {
                                final x = handleSize + c * (cellWidth + cellSpacing);
                                final y = handleSize + r * (cellHeight + cellSpacing);
                                return Positioned(
                                  left: x,
                                  top: y,
                                  child: Container(
                                    width: cellWidth,
                                    height: cellHeight,
                                    decoration: BoxDecoration(
                                      color: AppColors.borderSubtle,
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                  ),
                                );
                              });
                            }).expand((e) => e),

                            // 2. Row handles
                            ...List.generate(8, (r) {
                              final y = handleSize + r * (cellHeight + cellSpacing);
                              return Positioned(
                                left: 0,
                                top: y,
                                child: RowHandleWidget(index: r),
                              );
                            }),

                            // 3. Column handles
                            ...List.generate(6, (c) {
                              final x = handleSize + c * (cellWidth + cellSpacing);
                              return Positioned(
                                left: x,
                                top: 0,
                                child: ColHandleWidget(index: c),
                              );
                            }),

                            // 4. Tool 2 — column footers
                            if (activeTool == 2)
                              ...List.generate(6, (c) {
                                final x = handleSize + c * (cellWidth + cellSpacing);
                                final y = handleSize + 8 * (cellHeight + cellSpacing);
                                final isEven = c % 2 == 0;
                                return Positioned(
                                  left: x,
                                  top: y,
                                  child: RepaintBoundary(
                                    child: SizedBox(
                                      width: cellWidth,
                                      height: handleSize,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: (isEven
                                                    ? AppColors.success
                                                    : AppColors.error)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(AppRadius.pill),
                                          ),
                                          child: Text(
                                            isEven ? '0' : '≠ 0',
                                            style: AppTextStyles.caption(
                                              color: isEven
                                                  ? AppColors.success
                                                  : AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                            // 5. Tool 3 — row side hints
                            if (activeTool == 3)
                              ...List.generate(8, (r) {
                                final x = handleSize + 6 * (cellWidth + cellSpacing);
                                final y = handleSize + r * (cellHeight + cellSpacing);
                                final isEven = r % 2 == 0;
                                return Positioned(
                                  left: x,
                                  top: y,
                                  child: RepaintBoundary(
                                    child: SizedBox(
                                      width: cellWidth,
                                      height: cellHeight,
                                      child: Center(
                                        child: Text(
                                          isEven ? '3L / 3D' : '4L / 2D',
                                          style: AppTextStyles.code(
                                            color: isEven
                                                ? AppColors.success
                                                : AppColors.error,
                                            size: 11.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                            // 6. Animated grid cells
                            ...state.cellIds.map((id) {
                              return CellPositionedSelector(cellId: id);
                            }),

                            // 7. Tool 5 — quadrant symmetry overlay
                            if (activeTool == 5)
                              IgnorePointer(
                                child: RepaintBoundary(
                                  child: Stack(
                                    children: [
                                      _buildQuadrantBorder(0, 0, AppColors.success),
                                      _buildQuadrantBorder(1, 0, AppColors.error),
                                      _buildQuadrantBorder(0, 1, AppColors.error),
                                      _buildQuadrantBorder(1, 1, AppColors.success),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrantBorder(int quadX, int quadY, Color color) {
    final qWidth  = 3 * cellWidth  + 2 * cellSpacing + 6.0;
    final qHeight = 4 * cellHeight + 3 * cellSpacing + 6.0;
    final x = handleSize + quadX * 3 * (cellWidth + cellSpacing) - 3.0;
    final y = handleSize + quadY * 4 * (cellHeight + cellSpacing) - 3.0;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: qWidth,
        height: qHeight,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.7), width: 2.0),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ToolSelector — horizontal scrolling pill group with animated indicator
// ---------------------------------------------------------------------------
class _ToolSelector extends StatelessWidget {
  final int activeTool;
  final void Function(int) onSelect;

  const _ToolSelector({required this.activeTool, required this.onSelect});

  static const List<String> _labels = [
    'None', 'Color', 'Mod 36', 'Balance', 'Adjacent', 'Symmetry', 'Semantic',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_labels.length, (i) {
            final isSelected = activeTool == i;
            return GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppDurations.normal,
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.surfaceHigh
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: AppDurations.fast,
                  style: GoogleFonts.inter(
                    fontSize: 12.0,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                  child: Text(_labels[i]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RowHandleState / ColHandleState
// ---------------------------------------------------------------------------
class _HandleState {
  final bool isSelected;
  final bool isDimmed;
  final bool isCharacterMode;

  const _HandleState({
    required this.isSelected,
    required this.isDimmed,
    required this.isCharacterMode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HandleState &&
          isSelected == other.isSelected &&
          isDimmed == other.isDimmed &&
          isCharacterMode == other.isCharacterMode;

  @override
  int get hashCode => Object.hash(isSelected, isDimmed, isCharacterMode);
}

// ---------------------------------------------------------------------------
// RowHandleWidget
// ---------------------------------------------------------------------------
class RowHandleWidget extends StatefulWidget {
  final int index;
  const RowHandleWidget({super.key, required this.index});

  @override
  State<RowHandleWidget> createState() => _RowHandleWidgetState();
}

class _RowHandleWidgetState extends State<RowHandleWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return RepaintBoundary(
      child: Selector<GridState, _HandleState>(
        selector: (_, s) => _HandleState(
          isSelected: s.selectedRowIndex == widget.index,
          isDimmed: s.draggingRowIndex != null && s.draggingRowIndex != widget.index,
          isCharacterMode: s.isCharacterMode,
        ),
        builder: (context, hs, _) {
          final iconColor = (hs.isSelected || _hovered)
              ? AppColors.textSecondary
              : AppColors.textMuted;

          final handleVisual = MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: () => state.handleRowTap(widget.index),
              child: AnimatedOpacity(
                duration: AppDurations.fast,
                opacity: hs.isDimmed ? 0.35 : 1.0,
                child: SizedBox(
                  width: PuzzleBoard.handleSize,
                  height: PuzzleBoard.cellHeight,
                  child: Center(
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: iconColor,
                        size: 18.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          if (hs.isCharacterMode) return handleVisual;

          return Draggable<int>(
            data: widget.index,
            ignoringFeedbackSemantics: true,
            feedback: Material(
              color: Colors.transparent,
              child: Icon(Icons.drag_indicator_rounded,
                  color: AppColors.textPrimary, size: 18.0),
            ),
            childWhenDragging: Opacity(
              opacity: 0.2,
              child: handleVisual,
            ),
            onDragStarted: () => state.setDraggingRow(widget.index),
            onDragEnd: (_) => state.setDraggingRow(null),
            child: DragTarget<int>(
              onWillAcceptWithDetails: (d) => d.data != widget.index,
              onAcceptWithDetails: (d) => state.swapRows(d.data, widget.index),
              builder: (ctx, c, r) => handleVisual,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ColHandleWidget
// ---------------------------------------------------------------------------
class ColHandleWidget extends StatefulWidget {
  final int index;
  const ColHandleWidget({super.key, required this.index});

  @override
  State<ColHandleWidget> createState() => _ColHandleWidgetState();
}

class _ColHandleWidgetState extends State<ColHandleWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return RepaintBoundary(
      child: Selector<GridState, _HandleState>(
        selector: (_, s) => _HandleState(
          isSelected: s.selectedColIndex == widget.index,
          isDimmed: s.draggingColIndex != null && s.draggingColIndex != widget.index,
          isCharacterMode: s.isCharacterMode,
        ),
        builder: (context, hs, _) {
          final iconColor = (hs.isSelected || _hovered)
              ? AppColors.textSecondary
              : AppColors.textMuted;

          final handleVisual = MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: () => state.handleColTap(widget.index),
              child: AnimatedOpacity(
                duration: AppDurations.fast,
                opacity: hs.isDimmed ? 0.35 : 1.0,
                child: SizedBox(
                  width: PuzzleBoard.cellWidth,
                  height: PuzzleBoard.handleSize,
                  child: Center(
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: iconColor,
                      size: 18.0,
                    ),
                  ),
                ),
              ),
            ),
          );

          if (hs.isCharacterMode) return handleVisual;

          return Draggable<int>(
            data: widget.index,
            ignoringFeedbackSemantics: true,
            feedback: Material(
              color: Colors.transparent,
              child: Icon(Icons.drag_indicator_rounded,
                  color: AppColors.textPrimary, size: 18.0),
            ),
            childWhenDragging: Opacity(opacity: 0.2, child: handleVisual),
            onDragStarted: () => state.setDraggingCol(widget.index),
            onDragEnd: (_) => state.setDraggingCol(null),
            child: DragTarget<int>(
              onWillAcceptWithDetails: (d) => d.data != widget.index,
              onAcceptWithDetails: (d) => state.swapCols(d.data, widget.index),
              builder: (ctx, c, r) => handleVisual,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CellRenderState — equality object for targeted rebuilds
// ---------------------------------------------------------------------------
class CellRenderState {
  final GridCell cell;
  final bool isSelected;
  final bool isDimmed;
  final int activeTool;

  const CellRenderState({
    required this.cell,
    required this.isSelected,
    required this.isDimmed,
    required this.activeTool,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellRenderState &&
          cell.currentCol == other.cell.currentCol &&
          cell.currentRow == other.cell.currentRow &&
          cell.codeText == other.cell.codeText &&
          cell.secretLetter == other.cell.secretLetter &&
          cell.color == other.cell.color &&
          isSelected == other.isSelected &&
          isDimmed == other.isDimmed &&
          activeTool == other.activeTool;

  @override
  int get hashCode => Object.hash(
        cell.currentCol, cell.currentRow, cell.codeText,
        cell.secretLetter, isSelected, isDimmed, activeTool,
      );
}

// ---------------------------------------------------------------------------
// CellPositionedSelector — AnimatedPositioned per cell
// ---------------------------------------------------------------------------
class CellPositionedSelector extends StatelessWidget {
  final String cellId;
  const CellPositionedSelector({super.key, required this.cellId});

  @override
  Widget build(BuildContext context) {
    return Selector<GridState, CellRenderState>(
      selector: (_, s) => CellRenderState(
        cell: s.getCellById(cellId),
        isSelected: s.selectedCellId == cellId,
        isDimmed: s.draggingCellId != null && s.draggingCellId != cellId,
        activeTool: s.activeTool,
      ),
      builder: (context, rs, _) {
        final x = PuzzleBoard.handleSize +
            rs.cell.currentCol * (PuzzleBoard.cellWidth + PuzzleBoard.cellSpacing);
        final y = PuzzleBoard.handleSize +
            rs.cell.currentRow * (PuzzleBoard.cellHeight + PuzzleBoard.cellSpacing);

        return AnimatedPositioned(
          key: ValueKey(rs.cell.id),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          left: x,
          top: y,
          child: CellInteractionWidget(
            cell: rs.cell,
            isSelected: rs.isSelected,
            isDimmed: rs.isDimmed,
            activeTool: rs.activeTool,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// CellInteractionWidget — drag + tap + visual
// ---------------------------------------------------------------------------
class CellInteractionWidget extends StatefulWidget {
  final GridCell cell;
  final bool isSelected;
  final bool isDimmed;
  final int activeTool;

  const CellInteractionWidget({
    super.key,
    required this.cell,
    required this.isSelected,
    required this.isDimmed,
    required this.activeTool,
  });

  @override
  State<CellInteractionWidget> createState() => _CellInteractionWidgetState();
}

class _CellInteractionWidgetState extends State<CellInteractionWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);
    final isActive = widget.isSelected || _hovered;
    final isChar = widget.activeTool == 6;

    Widget cellContent = RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => state.handleCellTap(widget.cell.id),
          child: _CellVisual(
            cell: widget.cell,
            isActive: isActive,
            isDimmed: widget.isDimmed,
            activeTool: widget.activeTool,
          ),
        ),
      ),
    );

    if (isChar) return cellContent;

    return Draggable<String>(
      data: widget.cell.id,
      ignoringFeedbackSemantics: true,
      feedback: Material(
        color: Colors.transparent,
        child: _CellVisual(
          cell: widget.cell,
          isActive: true,
          isDimmed: false,
          activeTool: widget.activeTool,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _CellVisual(
          cell: widget.cell,
          isActive: false,
          isDimmed: false,
          activeTool: widget.activeTool,
        ),
      ),
      onDragStarted: () => state.setDraggingCell(widget.cell.id),
      onDragEnd: (_) => state.setDraggingCell(null),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != widget.cell.id,
        onAcceptWithDetails: (d) => state.swapCells(d.data, widget.cell.id),
        builder: (ctx, c, r) => cellContent,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CellVisual — purely visual, stateless cell rendering
// ---------------------------------------------------------------------------
class _CellVisual extends StatelessWidget {
  final GridCell cell;
  final bool isActive;
  final bool isDimmed;
  final int activeTool;

  const _CellVisual({
    required this.cell,
    required this.isActive,
    required this.isDimmed,
    required this.activeTool,
  });

  @override
  Widget build(BuildContext context) {
    final isChar  = activeTool == 6;
    final cellIdx = cell.currentRow * 6 + cell.currentCol;

    // Background color
    final bg = isChar
        ? AppColors.textPrimary
        : (isActive ? AppColors.textPrimary : AppColors.surfaceHigh);

    // Text color
    Color textCol = isChar
        ? AppColors.background
        : (isActive ? AppColors.background : AppColors.textPrimary);

    // Tool 4 — adjacency text coloring
    if (activeTool == 4) {
      final isThird = cellIdx % 3 == 0;
      textCol = isThird ? AppColors.success : AppColors.error;
    }

    // Tool 1 — colored glow ring
    Color? glowColor;
    if (activeTool == 1) {
      glowColor = cellIdx % 2 == 0 ? AppColors.success : AppColors.error;
    }

    return AnimatedOpacity(
      duration: AppDurations.fast,
      opacity: isDimmed ? 0.3 : 1.0,
      child: AnimatedScale(
        duration: AppDurations.fast,
        scale: isActive ? 1.04 : 1.0,
        child: Container(
          width: PuzzleBoard.cellWidth,
          height: PuzzleBoard.cellHeight,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (isChar ? AppColors.textPrimary : cell.color)
                          .withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ]
                : glowColor != null
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
          ),
          child: Stack(
            children: [
              // Concept color left accent strip (not in char mode)
              if (!isChar)
                Positioned(
                  left: 0,
                  top: 4,
                  bottom: 4,
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    width: 3.0,
                    decoration: BoxDecoration(
                      color: isActive
                          ? cell.color.withValues(alpha: 0.7)
                          : cell.color.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),

              // Code text / Secret letter
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    isChar ? cell.secretLetter : cell.codeText,
                    style: AppTextStyles.code(
                      color: textCol,
                      size: isChar ? 15.0 : 11.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'grid_cell.dart';
import 'grid_state.dart';
import 'theme.dart';
import 'widgets/image_gallery_dialog.dart';

class PuzzleBoard extends StatelessWidget {
  const PuzzleBoard({super.key});

  static const double cellWidth   = 48.0;
  static const double cellHeight  = 28.0;
  static const double cellSpacing = 4.0;
  static const double handleSize  = 24.0;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Column(
      children: [
        // ── Header ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
          child: Selector<GridState, int>(
            selector: (_, s) => s.activeTool,
            builder: (context, activeTool, _) {
              final toolColors = {
                1: AppColors.conceptPurple,
                2: AppColors.conceptBlue,
                3: AppColors.conceptTeal,
                4: AppColors.conceptOrange,
                5: AppColors.conceptRose,
              };
              final toolColor = toolColors[activeTool];
              final label = activeTool == 0
                  ? ''
                  : [
                      'Debe haber solo un color por columna.',
                      'La suma de los últimos caracteres de la columna debe ser 0 en base 36.',
                      'Debe haber la misma cantidad de digitos y letras en cada fila.',
                      'Los vecinos deben tener exactamente un carácter en común.',
                      'Los centros y los extremos deben ser el inverso del otro.',
                    ][activeTool - 1];
              return AnimatedSwitcher(
                duration: AppDurations.fast,
                child: label.isEmpty
                    ? const SizedBox.shrink()
                    : Row(
                        key: ValueKey(activeTool),
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (toolColor != null) ...[
                            Container(
                              width: 8.0,
                              height: 8.0,
                              decoration: BoxDecoration(
                                color: toolColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: toolColor.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8.0),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption(
                                color: activeTool > 0
                                    ? AppColors.textSecondary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
        ),


        // ── Board ────────────────────────────────────────────────────────
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: Selector<GridState, int>(
              selector: (_, s) => s.activeTool,
              builder: (context, activeTool, _) {
                // Dimensions locked in place to prevent the grid shifting on tool change
                final double totalWidth = handleSize +
                    7 * (cellWidth + cellSpacing) +
                    16.0;
                final double totalHeight = handleSize +
                    8 * (cellHeight + cellSpacing) +
                    (handleSize + cellSpacing) +
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
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
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

                                // Calculate sum of last characters in base 36
                                int sum = 0;
                                for (int r = 0; r < 8; r++) {
                                  final cell = state.getCellAt(c, r);
                                  if (cell != null && cell.codeText.isNotEmpty) {
                                    final lastChar = cell.codeText[cell.codeText.length - 1];
                                    sum += getBase36Value(lastChar);
                                  }
                                }
                                final isValid = (sum % 36 == 0);

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
                                              horizontal: 8.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: (isValid
                                                    ? AppColors.success
                                                    : AppColors.error)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(AppRadius.pill),
                                          ),
                                          child: Icon(
                                            isValid
                                                ? Icons.check_circle_outline_rounded
                                                : Icons.cancel_outlined,
                                            size: 12.0,
                                            color: isValid
                                                ? AppColors.success
                                                : AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                            // 5. Tool 3 — row side hints (styled like column footers)
                            if (activeTool == 3)
                              ...List.generate(8, (r) {
                                final x = handleSize + 6 * (cellWidth + cellSpacing) + 8.0;
                                final y = handleSize + r * (cellHeight + cellSpacing);
                                final isBalanced = checkRowBalance(context, r);
                                return Positioned(
                                  left: x,
                                  top: y,
                                  child: RepaintBoundary(
                                    child: SizedBox(
                                      width: 32.0,
                                      height: cellHeight,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: (isBalanced
                                                    ? AppColors.success
                                                    : AppColors.error)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(AppRadius.pill),
                                          ),
                                          child: Icon(
                                            isBalanced
                                                ? Icons.check_circle_outline_rounded
                                                : Icons.cancel_outlined,
                                            size: 12.0,
                                            color: isBalanced
                                                ? AppColors.success
                                                : AppColors.error,
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

                            // 7. Tool 5 — quadrant symmetry overlay (Pointed Lines Painter)
                            if (activeTool == 5)
                              IgnorePointer(
                                child: RepaintBoundary(
                                  child: Positioned.fill(
                                    child: CustomPaint(
                                      painter: SymmetryLinePainter(
                                        state: state,
                                        cellWidth: cellWidth,
                                        cellHeight: cellHeight,
                                        cellSpacing: cellSpacing,
                                        handleSize: handleSize,
                                      ),
                                    ),
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

        // ── Action Buttons ───────────────────────────────────────────────
        ListenableBuilder(
          listenable: state,
          builder: (ctx, _) {
            final solved = state.isGridSolved;
            return Container(
              margin: const EdgeInsets.only(top: 8.0, bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Scramble Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => state.scrambleGrid(),
                      child: AnimatedContainer(
                        duration: AppDurations.normal,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: solved ? AppColors.success : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: [
                            BoxShadow(
                              color: (solved ? AppColors.success : Colors.white).withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'SCRAMBLE',
                          style: AppTextStyles.label(
                            color: solved ? Colors.white : AppColors.background,
                          ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  // Check Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => state.checkGrid(ctx),
                      child: AnimatedContainer(
                        duration: AppDurations.normal,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: solved ? AppColors.success : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (solved ? AppColors.success : Colors.white).withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20.0,
                          color: solved ? Colors.white : AppColors.background,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
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
  final int revealedCount;
  final bool isProgressiveLoading;

  const CellRenderState({
    required this.cell,
    required this.isSelected,
    required this.isDimmed,
    required this.activeTool,
    required this.revealedCount,
    required this.isProgressiveLoading,
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
          activeTool == other.activeTool &&
          revealedCount == other.revealedCount &&
          isProgressiveLoading == other.isProgressiveLoading;

  @override
  int get hashCode => Object.hash(
        cell.currentCol, cell.currentRow, cell.codeText,
        cell.secretLetter, isSelected, isDimmed, activeTool,
        revealedCount, isProgressiveLoading,
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
        revealedCount: s.revealedCount,
        isProgressiveLoading: s.isProgressiveLoading,
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
    final state = Provider.of<GridState>(context, listen: false);
    final int slotIndex = cell.currentRow * 6 + cell.currentCol;
    final bool isProgressiveHidden = state.isProgressiveLoading && slotIndex >= state.revealedCount;
    final bool isEmptySlot = isProgressiveHidden || cell.codeText.isEmpty;

    final isChar  = activeTool == 6;

    // Tool 1 — valid HEX coloring
    Color? hexColor;
    if (activeTool == 1 && !isEmptySlot) {
      final upperCode = cell.codeText.toUpperCase().trim();
      final validHexCodes = {'B17A41', '9BC8E2', 'ABCA43', 'DDD1D2', 'D6A371', 'B48EF1'};
      if (validHexCodes.contains(upperCode)) {
        hexColor = Color(int.parse('FF$upperCode', radix: 16));
      }
    }

    // Background color
    final bg = isEmptySlot
        ? AppColors.surfaceHigh
        : (isChar
            ? AppColors.textPrimary
            : (activeTool == 1 && hexColor != null
                ? hexColor
                : (isActive ? AppColors.textPrimary : AppColors.surfaceHigh)));

    // Text color
    Color textCol = isEmptySlot
        ? Colors.transparent
        : (isChar
            ? AppColors.background
            : (activeTool == 1 && hexColor != null
                ? AppColors.background
                : (isActive ? AppColors.background : AppColors.textPrimary)));

    // Tool 4 — adjacency text coloring
    if (activeTool == 4 && !isEmptySlot) {
      final isValid = checkAdjacency(context, cell);
      textCol = isValid ? AppColors.success : AppColors.error;
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
            boxShadow: (isActive && !isEmptySlot)
                ? [
                    BoxShadow(
                      color: (isChar ? AppColors.textPrimary : cell.color)
                          .withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              isEmptySlot ? '' : (isChar ? cell.secretLetter : cell.codeText),
              style: AppTextStyles.code(
                color: textCol,
                size: isChar ? 12.0 : 8.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LoadImageButton — ghost pill in the grid header that opens the image
// gallery dialog showing all uploaded images from Supabase Storage.
// ---------------------------------------------------------------------------
class LoadImageButton extends StatefulWidget {
  const LoadImageButton({super.key});

  @override
  State<LoadImageButton> createState() => _LoadImageButtonState();
}

class _LoadImageButtonState extends State<LoadImageButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => const ImageGalleryDialog(),
        ),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHigh : AppColors.borderSubtle,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.photo_library_outlined,
            size: 14,
            color: _hovered
                ? AppColors.textSecondary
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tool Helpers
// ---------------------------------------------------------------------------

int getBase36Value(String char) {
  final codeUnit = char.codeUnitAt(0);
  if (codeUnit >= 48 && codeUnit <= 57) { // '0'-'9'
    return codeUnit - 48;
  } else if (codeUnit >= 65 && codeUnit <= 90) { // 'A'-'Z'
    return codeUnit - 55;
  } else if (codeUnit >= 97 && codeUnit <= 122) { // 'a'-'z'
    return codeUnit - 87;
  }
  return 0;
}

bool checkRowBalance(BuildContext context, int row) {
  final state = Provider.of<GridState>(context, listen: false);
  int letterCount = 0;
  int digitCount = 0;

  for (int col = 0; col < 6; col++) {
    final cell = state.getCellAt(col, row);
    if (cell == null) continue;
    for (final char in cell.codeText.split('')) {
      final codeUnit = char.codeUnitAt(0);
      if (codeUnit >= 48 && codeUnit <= 57) {
        digitCount++;
      } else if ((codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122)) {
        letterCount++;
      }
    }
  }
  return letterCount == digitCount;
}

bool checkAdjacency(BuildContext context, GridCell cell) {
  final state = Provider.of<GridState>(context, listen: false);
  final col = cell.currentCol;
  final row = cell.currentRow;

  final neighbors = <GridCell>[];
  final up = state.getCellAt(col, row - 1);
  if (up != null) neighbors.add(up);
  final down = state.getCellAt(col, row + 1);
  if (down != null) neighbors.add(down);
  final left = state.getCellAt(col - 1, row);
  if (left != null) neighbors.add(left);
  final right = state.getCellAt(col + 1, row);
  if (right != null) neighbors.add(right);

  final cellChars = cell.codeText.split('').toSet();

  for (final nb in neighbors) {
    final nbChars = nb.codeText.split('').toSet();
    final common = cellChars.intersection(nbChars);
    if (common.length != 1) {
      return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------------------
// SymmetryLinePainter — draws dashed pointed lines connecting symmetry pairs
// ---------------------------------------------------------------------------
class SymmetryLinePainter extends CustomPainter {
  final GridState state;
  final double cellWidth;
  final double cellHeight;
  final double cellSpacing;
  final double handleSize;

  const SymmetryLinePainter({
    required this.state,
    required this.cellWidth,
    required this.cellHeight,
    required this.cellSpacing,
    required this.handleSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pairs = [
      [const Point(0, 0), const Point(2, 3)],
      [const Point(5, 0), const Point(3, 3)],
      [const Point(0, 7), const Point(2, 4)],
      [const Point(5, 7), const Point(3, 4)],
    ];

    for (final pair in pairs) {
      final p1 = pair[0];
      final p2 = pair[1];

      final cellA = state.getCellAt(p1.x, p1.y);
      final cellB = state.getCellAt(p2.x, p2.y);

      if (cellA == null || cellB == null) continue;

      final startPos = _getCellCenter(p1.x, p1.y);
      final endPos = _getCellCenter(p2.x, p2.y);

      final isCorrect = cellA.codeText == cellB.codeText.split('').reversed.join();
      final color = isCorrect ? AppColors.success : AppColors.error;

      _drawDashedLine(canvas, startPos, endPos, color);
    }
  }

  Offset _getCellCenter(int col, int row) {
    final x = handleSize + col * (cellWidth + cellSpacing) + cellWidth / 2;
    final y = handleSize + row * (cellHeight + cellSpacing) + cellHeight / 2;
    return Offset(x, y);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    // Soft outer glow layer
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    _paintDashedPath(canvas, p1, p2, glowPaint);

    // Main visible line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _paintDashedPath(canvas, p1, p2, linePaint);

    // Endpoint dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(p1, 4.0, dotPaint);
    canvas.drawCircle(p2, 4.0, dotPaint);
  }

  void _paintDashedPath(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;
    
    final direction = Offset(dx / distance, dy / distance);
    double currentDistance = 0.0;
    
    while (currentDistance < distance) {
      final start = p1 + direction * currentDistance;
      final endDistance = (currentDistance + dashWidth).clamp(0.0, distance);
      final end = p1 + direction * endDistance;
      canvas.drawLine(start, end, paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant SymmetryLinePainter oldDelegate) {
    return true; // Live update on grid layout state changes
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'grid_cell.dart';
import 'grid_state.dart';

class PuzzleBoard extends StatelessWidget {
  const PuzzleBoard({super.key});

  // Strict layout dimensions for 3:1 aspect ratio grid cells
  static const double cellWidth = 120.0;
  static const double cellHeight = 40.0;
  static const double cellSpacing = 8.0;
  static const double handleSize = 32.0;

  @override
  Widget build(BuildContext context) {
    // Read state without listening to prevent rebuilds of the entire board
    final state = Provider.of<GridState>(context, listen: false);

    // Calculate exact board dimensions
    final double totalWidth = handleSize + 6 * (cellWidth + cellSpacing) + 16.0;
    final double totalHeight = handleSize + 8 * (cellHeight + cellSpacing) + 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Zinc 950
      body: SafeArea(
        child: Column(
          children: [
            // Shadcn Title Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Column(
                children: [
                  const Text(
                    "GRID DECRYPTOR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Selector<GridState, bool>(
                    selector: (_, s) => s.isCharacterMode,
                    builder: (context, isCharMode, _) {
                      return Text(
                        isCharMode
                            ? "DECIPHER MODE"
                            : "STABILIZATION MODE",
                        style: TextStyle(
                          color: isCharMode ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Board Container
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: GestureDetector(
                      onTap: () => state.clearSelection(),
                      child: Container(
                        width: totalWidth,
                        height: totalHeight,
                        margin: const EdgeInsets.all(16.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF09090B),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: const Color(0xFF27272A), // Zinc 800
                            width: 1.0,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // 1. Grid Background lines / place slots (visual support)
                            ...List.generate(8, (r) {
                              return List.generate(6, (c) {
                                final double x = handleSize + c * (cellWidth + cellSpacing);
                                final double y = handleSize + r * (cellHeight + cellSpacing);
                                return Positioned(
                                  left: x,
                                  top: y,
                                  child: Container(
                                    width: cellWidth,
                                    height: cellHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(
                                        color: const Color(0xFF18181B), // Zinc 900
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                );
                              });
                            }).expand((e) => e),

                            // 2. Row Handles (Left Column)
                            ...List.generate(8, (r) {
                              final double x = 0;
                              final double y = handleSize + r * (cellHeight + cellSpacing);
                              return Positioned(
                                left: x,
                                top: y,
                                child: RowHandleWidget(index: r),
                              );
                            }),

                            // 3. Column Handles (Top Row)
                            ...List.generate(6, (c) {
                              final double x = handleSize + c * (cellWidth + cellSpacing);
                              final double y = 0;
                              return Positioned(
                                left: x,
                                top: y,
                                child: ColHandleWidget(index: c),
                              );
                            }),

                            // 4. Optimized Grid Cells
                            ...state.cellIds.map((id) {
                              return CellPositionedSelector(cellId: id);
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom control switch (Shadcn style)
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Selector<GridState, bool>(
                selector: (_, s) => s.isCharacterMode,
                builder: (context, isCharMode, _) {
                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isCharMode ? Colors.black : Colors.white,
                      backgroundColor: isCharMode ? Colors.white : Colors.transparent,
                      side: const BorderSide(color: Color(0xFF27272A)),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                    ),
                    onPressed: () => state.toggleCharacterMode(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCharMode ? Icons.visibility : Icons.tune,
                          size: 16.0,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          isCharMode
                              ? "ARRANGEMENT MODE"
                              : "CHARACTER MODE",
                          style: const TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- STATE SPECIFIC FOR ROW HANDLE SELECTION/DRAG ---
class RowHandleState {
  final bool isSelected;
  final bool isDimmed;
  final bool isCharacterMode;

  RowHandleState({
    required this.isSelected,
    required this.isDimmed,
    required this.isCharacterMode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RowHandleState &&
          runtimeType == other.runtimeType &&
          isSelected == other.isSelected &&
          isDimmed == other.isDimmed &&
          isCharacterMode == other.isCharacterMode;

  @override
  int get hashCode => Object.hash(isSelected, isDimmed, isCharacterMode);
}

// --- ROW HANDLE WIDGET (TARGETED REBUILD) ---
class RowHandleWidget extends StatefulWidget {
  final int index;
  const RowHandleWidget({super.key, required this.index});

  @override
  State<RowHandleWidget> createState() => _RowHandleWidgetState();
}

class _RowHandleWidgetState extends State<RowHandleWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return RepaintBoundary(
      child: Selector<GridState, RowHandleState>(
        selector: (_, s) => RowHandleState(
          isSelected: s.selectedRowIndex == widget.index,
          isDimmed: s.draggingRowIndex != null && s.draggingRowIndex != widget.index,
          isCharacterMode: s.isCharacterMode,
        ),
        builder: (context, renderState, _) {
          final isSelected = renderState.isSelected;
          final isDimmed = renderState.isDimmed;
          final isChar = renderState.isCharacterMode;

          Widget handleVisual = MouseRegion(
            onEnter: (_) => setState(() => isHovered = true),
            onExit: (_) => setState(() => isHovered = false),
            child: GestureDetector(
              onTap: () => state.handleRowTap(widget.index),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isDimmed ? 0.5 : 1.0,
                child: SizedBox(
                  width: PuzzleBoard.handleSize,
                  height: PuzzleBoard.cellHeight,
                  child: Center(
                    child: Icon(
                      Icons.drag_indicator,
                      color: (isSelected || isHovered)
                          ? Colors.white
                          : const Color(0xFF3F3F46), // Zinc 700
                      size: 20.0,
                    ),
                  ),
                ),
              ),
            ),
          );

          if (isChar) {
            return handleVisual;
          }

          return Draggable<int>(
            data: widget.index,
            ignoringFeedbackSemantics: true,
            feedback: Material(
              color: Colors.transparent,
              child: RepaintBoundary(
                child: SizedBox(
                  width: PuzzleBoard.handleSize,
                  height: PuzzleBoard.cellHeight,
                  child: const Center(
                    child: Icon(
                      Icons.drag_indicator,
                      color: Colors.white,
                      size: 20.0,
                    ),
                  ),
                ),
              ),
            ),
            childWhenDragging: const Opacity(
              opacity: 0.3,
              child: SizedBox(
                width: PuzzleBoard.handleSize,
                height: PuzzleBoard.cellHeight,
                child: Center(
                  child: Icon(
                    Icons.drag_indicator,
                    color: Color(0xFF27272A),
                    size: 20.0,
                  ),
                ),
              ),
            ),
            onDragStarted: () => state.setDraggingRow(widget.index),
            onDragEnd: (_) => state.setDraggingRow(null),
            child: DragTarget<int>(
              onWillAcceptWithDetails: (details) => details.data != widget.index,
              onAcceptWithDetails: (details) {
                state.swapRows(details.data, widget.index);
              },
              builder: (context, candidateData, rejectedData) {
                return handleVisual;
              },
            ),
          );
        },
      ),
    );
  }
}

// --- COL HANDLE WIDGET (TARGETED REBUILD) ---
class ColHandleWidget extends StatefulWidget {
  final int index;
  const ColHandleWidget({super.key, required this.index});

  @override
  State<ColHandleWidget> createState() => _ColHandleWidgetState();
}

class _ColHandleWidgetState extends State<ColHandleWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return RepaintBoundary(
      child: Selector<GridState, RowHandleState>(
        selector: (_, s) => RowHandleState(
          isSelected: s.selectedColIndex == widget.index,
          isDimmed: s.draggingColIndex != null && s.draggingColIndex != widget.index,
          isCharacterMode: s.isCharacterMode,
        ),
        builder: (context, renderState, _) {
          final isSelected = renderState.isSelected;
          final isDimmed = renderState.isDimmed;
          final isChar = renderState.isCharacterMode;

          Widget handleVisual = MouseRegion(
            onEnter: (_) => setState(() => isHovered = true),
            onExit: (_) => setState(() => isHovered = false),
            child: GestureDetector(
              onTap: () => state.handleColTap(widget.index),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isDimmed ? 0.5 : 1.0,
                child: SizedBox(
                  width: PuzzleBoard.cellWidth,
                  height: PuzzleBoard.handleSize,
                  child: Center(
                    child: Icon(
                      Icons.drag_indicator,
                      color: (isSelected || isHovered)
                          ? Colors.white
                          : const Color(0xFF3F3F46), // Zinc 700
                      size: 20.0,
                    ),
                  ),
                ),
              ),
            ),
          );

          if (isChar) {
            return handleVisual;
          }

          return Draggable<int>(
            data: widget.index,
            ignoringFeedbackSemantics: true,
            feedback: Material(
              color: Colors.transparent,
              child: RepaintBoundary(
                child: SizedBox(
                  width: PuzzleBoard.cellWidth,
                  height: PuzzleBoard.handleSize,
                  child: const Center(
                    child: Icon(
                      Icons.drag_indicator,
                      color: Colors.white,
                      size: 20.0,
                    ),
                  ),
                ),
              ),
            ),
            childWhenDragging: const Opacity(
              opacity: 0.3,
              child: SizedBox(
                width: PuzzleBoard.cellWidth,
                height: PuzzleBoard.handleSize,
                child: Center(
                  child: Icon(
                    Icons.drag_indicator,
                    color: Color(0xFF27272A),
                    size: 20.0,
                  ),
                ),
              ),
            ),
            onDragStarted: () => state.setDraggingCol(widget.index),
            onDragEnd: (_) => state.setDraggingCol(null),
            child: DragTarget<int>(
              onWillAcceptWithDetails: (details) => details.data != widget.index,
              onAcceptWithDetails: (details) {
                state.swapCols(details.data, widget.index);
              },
              builder: (context, candidateData, rejectedData) {
                return handleVisual;
              },
            ),
          );
        },
      ),
    );
  }
}

// --- STATE SPECIFIC FOR CELL SELECTION/DRAG/COORDINATES ---
class CellRenderState {
  final GridCell cell;
  final bool isSelected;
  final bool isDimmed;
  final bool isCharacterMode;

  CellRenderState({
    required this.cell,
    required this.isSelected,
    required this.isDimmed,
    required this.isCharacterMode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellRenderState &&
          runtimeType == other.runtimeType &&
          cell.currentCol == other.cell.currentCol &&
          cell.currentRow == other.cell.currentRow &&
          cell.codeText == other.cell.codeText &&
          cell.secretLetter == other.cell.secretLetter &&
          cell.color == other.cell.color &&
          isSelected == other.isSelected &&
          isDimmed == other.isDimmed &&
          isCharacterMode == other.isCharacterMode;

  @override
  int get hashCode => Object.hash(cell.currentCol, cell.currentRow, cell.codeText, cell.secretLetter, isSelected, isDimmed, isCharacterMode);
}

// --- CELL POSITIONED SELECTOR (RESPONSIBLE FOR SLIDING & REBUILD FILTERING) ---
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
        isCharacterMode: s.isCharacterMode,
      ),
      builder: (context, renderState, _) {
        final cell = renderState.cell;

        // AnimatedPositioned handles the coordinate swap transition
        final double x = PuzzleBoard.handleSize + cell.currentCol * (PuzzleBoard.cellWidth + PuzzleBoard.cellSpacing);
        final double y = PuzzleBoard.handleSize + cell.currentRow * (PuzzleBoard.cellHeight + PuzzleBoard.cellSpacing);

        return AnimatedPositioned(
          key: ValueKey(cell.id),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          left: x,
          top: y,
          child: CellInteractionWidget(
            cell: cell,
            isSelected: renderState.isSelected,
            isDimmed: renderState.isDimmed,
            isCharacterMode: renderState.isCharacterMode,
          ),
        );
      },
    );
  }
}

// --- CELL INTERACTION WIDGET ---
class CellInteractionWidget extends StatefulWidget {
  final GridCell cell;
  final bool isSelected;
  final bool isDimmed;
  final bool isCharacterMode;

  const CellInteractionWidget({
    super.key,
    required this.cell,
    required this.isSelected,
    required this.isDimmed,
    required this.isCharacterMode,
  });

  @override
  State<CellInteractionWidget> createState() => _CellInteractionWidgetState();
}

class _CellInteractionWidgetState extends State<CellInteractionWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);
    final isActive = widget.isSelected || isHovered;

    Widget cellContent = RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: GestureDetector(
          onTap: () => state.handleCellTap(widget.cell.id),
          child: _buildCellVisual(isActive),
        ),
      ),
    );

    if (widget.isCharacterMode) {
      return cellContent;
    }

    return Draggable<String>(
      data: widget.cell.id,
      ignoringFeedbackSemantics: true,
      feedback: Material(
        color: Colors.transparent,
        child: RepaintBoundary(
          child: _buildCellVisual(true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCellVisual(false),
      ),
      onDragStarted: () => state.setDraggingCell(widget.cell.id),
      onDragEnd: (_) => state.setDraggingCell(null),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != widget.cell.id,
        onAcceptWithDetails: (details) {
          state.swapCells(details.data, widget.cell.id);
        },
        builder: (context, candidateData, rejectedData) {
          return cellContent;
        },
      ),
    );
  }

  // Purely visual cell layout
  Widget _buildCellVisual(bool isActive) {
    final bool charMode = widget.isCharacterMode;

    // Stark monochromatic shadcn theme color logic
    final Color bg = charMode
        ? Colors.white
        : (isActive ? Colors.white : Colors.black);

    final Color textCol = charMode
        ? Colors.black
        : (isActive ? Colors.black : Colors.white);

    final Color borderCol = charMode
        ? Colors.white
        : (isActive ? Colors.white : const Color(0xFF27272A)); // Zinc 800

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: widget.isDimmed ? 0.5 : 1.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: isActive ? 1.02 : 1.0,
        child: Container(
          width: PuzzleBoard.cellWidth,
          height: PuzzleBoard.cellHeight,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: borderCol,
              width: 1.0,
            ),
          ),
          child: Stack(
            children: [
              // Concept color - subtle 2px left border accent
              if (!charMode)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2.0,
                    decoration: BoxDecoration(
                      color: widget.cell.color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6.0),
                        bottomLeft: Radius.circular(6.0),
                      ),
                    ),
                  ),
                ),

              // Code or Secret Letter text (centered)
              Center(
                child: Text(
                  charMode ? widget.cell.secretLetter : widget.cell.codeText,
                  style: TextStyle(
                    color: textCol,
                    fontSize: charMode ? 14.0 : 12.0,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
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

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

  // Muted professional semantic colors (Shadcn style)
  static const Color colorSuccess = Color(0xFF10B981); // Emerald 500
  static const Color colorError = Color(0xFFF43F5E); // Rose 500

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Zinc 950
      body: SafeArea(
        child: Column(
          children: [
            // Shadcn Title Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
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
                  Selector<GridState, int>(
                    selector: (_, s) => s.activeTool,
                    builder: (context, activeTool, _) {
                      String subText = "STABILIZATION ACTIVE";
                      if (activeTool > 0) {
                        subText = "DECRYPTOR TOOL $activeTool ACTIVE";
                      }
                      return Text(
                        subText,
                        style: TextStyle(
                          color: activeTool == 6 ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
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

            // Minimalist Tool Selector UI (Row of Custom Segmented Buttons)
            Selector<GridState, int>(
              selector: (_, s) => s.activeTool,
              builder: (context, activeTool, _) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(7, (index) {
                        final isSelected = activeTool == index;
                        final String label = index == 0 ? "None" : "Tool $index";
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () => state.setActiveTool(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? Colors.white : const Color(0xFF27272A),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : const Color(0xFFA1A1AA),
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),

            // Board Container
            Expanded(
              child: Center(
                child: Selector<GridState, int>(
                  selector: (_, s) => s.activeTool,
                  builder: (context, activeTool, child) {
                    // Compute size dynamically depending on active tool extras
                    // Tool 2 adds a row footer at the bottom
                    // Tool 3 adds a column header/indicator at the far right
                    final double totalWidth = handleSize + 6 * (cellWidth + cellSpacing) + (activeTool == 3 ? cellWidth + cellSpacing : 0) + 16.0;
                    final double totalHeight = handleSize + 8 * (cellHeight + cellSpacing) + (activeTool == 2 ? handleSize + cellSpacing : 0) + 16.0;

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: GestureDetector(
                          onTap: () => state.clearSelection(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
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
                                // 1. Grid Background lines / place slots
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

                                // 4. Tool 2 Column Footers
                                if (activeTool == 2)
                                  ...List.generate(6, (c) {
                                    final double x = handleSize + c * (cellWidth + cellSpacing);
                                    final double y = handleSize + 8 * (cellHeight + cellSpacing);
                                    final bool isEven = c % 2 == 0;
                                    return Positioned(
                                      left: x,
                                      top: y,
                                      child: RepaintBoundary(
                                        child: SizedBox(
                                          width: cellWidth,
                                          height: handleSize,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                              decoration: BoxDecoration(
                                                color: (isEven ? colorSuccess : colorError).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12.0),
                                                border: Border.all(
                                                  color: isEven ? colorSuccess : colorError,
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Text(
                                                isEven ? "0" : "!= 0",
                                                style: TextStyle(
                                                  color: isEven ? colorSuccess : colorError,
                                                  fontSize: 10.0,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                // 5. Tool 3 Row Headers (Right Column)
                                if (activeTool == 3)
                                  ...List.generate(8, (r) {
                                    final double x = handleSize + 6 * (cellWidth + cellSpacing);
                                    final double y = handleSize + r * (cellHeight + cellSpacing);
                                    final bool isEven = r % 2 == 0;
                                    return Positioned(
                                      left: x,
                                      top: y,
                                      child: RepaintBoundary(
                                        child: SizedBox(
                                          width: cellWidth,
                                          height: cellHeight,
                                          child: Center(
                                            child: Text(
                                              isEven ? "3L / 3D" : "4L / 2D",
                                              style: TextStyle(
                                                color: isEven ? colorSuccess : colorError,
                                                fontSize: 11.0,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                // 6. Optimized Grid Cells
                                ...state.cellIds.map((id) {
                                  return CellPositionedSelector(cellId: id);
                                }),

                                // 7. Tool 5 Quadrant Symmetry Overlay (Ignore Pointer to avoid blocking interactions)
                                if (activeTool == 5)
                                  IgnorePointer(
                                    child: RepaintBoundary(
                                      child: Stack(
                                        children: [
                                          _buildQuadrantBorder(0, 0, colorSuccess), // Top-Left
                                          _buildQuadrantBorder(1, 0, colorError),   // Top-Right
                                          _buildQuadrantBorder(0, 1, colorError),   // Bottom-Left
                                          _buildQuadrantBorder(1, 1, colorSuccess), // Bottom-Right
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
        ),
      ),
    );
  }

  // Draw quadrant borders overlay helper
  Widget _buildQuadrantBorder(int quadX, int quadY, Color color) {
    final double qWidth = 3 * cellWidth + 2 * cellSpacing + 6.0;
    final double qHeight = 4 * cellHeight + 3 * cellSpacing + 6.0;

    final double x = handleSize + quadX * 3 * (cellWidth + cellSpacing) - 3.0;
    final double y = handleSize + quadY * 4 * (cellHeight + cellSpacing) - 3.0;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: qWidth,
        height: qHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: color,
            width: 3.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
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

// --- STATE SPECIFIC FOR CELL SELECTION/DRAG/COORDINATES/ACTIVE TOOL ---
class CellRenderState {
  final GridCell cell;
  final bool isSelected;
  final bool isDimmed;
  final int activeTool;

  CellRenderState({
    required this.cell,
    required this.isSelected,
    required this.isDimmed,
    required this.activeTool,
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
          activeTool == other.activeTool;

  @override
  int get hashCode => Object.hash(cell.currentCol, cell.currentRow, cell.codeText, cell.secretLetter, isSelected, isDimmed, activeTool);
}

// --- CELL POSITIONED SELECTOR ---
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
            activeTool: renderState.activeTool,
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
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);
    final isActive = widget.isSelected || isHovered;
    final bool isCharMode = widget.activeTool == 6;

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

    if (isCharMode) {
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

  // Purely visual cell layout with tool placeholder overlays
  Widget _buildCellVisual(bool isActive) {
    final int tool = widget.activeTool;
    final bool isChar = tool == 6;
    final int cellIndex = widget.cell.currentRow * 6 + widget.cell.currentCol;

    // Stark monochromatic colors
    final Color bg = isChar
        ? Colors.white
        : (isActive ? Colors.white : Colors.black);

    Color textCol = isChar
        ? Colors.black
        : (isActive ? Colors.black : Colors.white);

    Color borderCol = isChar
        ? Colors.white
        : (isActive ? Colors.white : const Color(0xFF27272A)); // Zinc 800

    // Tool 1 Placeholder Logic: Outline border green/red
    if (tool == 1) {
      final bool isEven = cellIndex % 2 == 0;
      borderCol = isEven ? PuzzleBoard.colorSuccess : PuzzleBoard.colorError;
    }

    // Tool 4 Placeholder Logic: Text color green/red
    if (tool == 4) {
      final bool isThird = cellIndex % 3 == 0;
      textCol = isThird ? PuzzleBoard.colorSuccess : PuzzleBoard.colorError;
    }

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
              width: tool == 1 ? 2.0 : 1.0, // Thicker border for Tool 1
            ),
          ),
          child: Stack(
            children: [
              // Concept color - subtle 2px left border accent (Not in Tool 6)
              if (!isChar)
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

              // Code text / Secret Letter
              Center(
                child: Text(
                  isChar ? widget.cell.secretLetter : widget.cell.codeText,
                  style: TextStyle(
                    color: textCol,
                    fontSize: isChar ? 14.0 : 12.0,
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

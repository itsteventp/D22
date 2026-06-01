import 'dart:math';
import 'package:flutter/material.dart';
import 'grid_cell.dart';

class GridState extends ChangeNotifier {
  List<GridCell> _cells = [];
  bool _isCharacterMode = false;

  // Selected cell/handle for Tap-to-Swap
  String? _selectedCellId;
  int? _selectedRowIndex;
  int? _selectedColIndex;

  // Drag state to help with dimming logic
  String? _draggingCellId;
  int? _draggingRowIndex;
  int? _draggingColIndex;

  List<GridCell> get cells => _cells;
  bool get isCharacterMode => _isCharacterMode;
  String? get selectedCellId => _selectedCellId;
  int? get selectedRowIndex => _selectedRowIndex;
  int? get selectedColIndex => _selectedColIndex;
  String? get draggingCellId => _draggingCellId;
  int? get draggingRowIndex => _draggingRowIndex;
  int? get draggingColIndex => _draggingColIndex;

  List<String> get cellIds => _cells.map((c) => c.id).toList();

  GridCell getCellById(String id) {
    return _cells.firstWhere((cell) => cell.id == id);
  }

  GridState() {
    generateInitialCells();
  }

  void toggleCharacterMode() {
    _isCharacterMode = !_isCharacterMode;
    // Clear selection when mode is toggled
    clearSelection();
    notifyListeners();
  }

  void setDraggingCell(String? cellId) {
    _draggingCellId = cellId;
    notifyListeners();
  }

  void setDraggingRow(int? rowIndex) {
    _draggingRowIndex = rowIndex;
    notifyListeners();
  }

  void setDraggingCol(int? colIndex) {
    _draggingColIndex = colIndex;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCellId = null;
    _selectedRowIndex = null;
    _selectedColIndex = null;
    notifyListeners();
  }

  // Generate initial state
  void generateInitialCells() {
    final Random rand = Random();
    final List<Color> conceptColors = [
      const Color(0xFF9b5de5), // Purple
      const Color(0xFFf15bb5), // Hot Pink / Magenta
      const Color(0xFF00f5d4), // Turquoise / Cyan
      const Color(0xFF00bbf9), // Blue
      const Color(0xFFfee440), // Yellow
      const Color(0xFFff9f1c), // Orange
      const Color(0xFF2ec4b6), // Teal
      const Color(0xFFe71d36), // Red
    ];

    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    _cells = [];

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 6; c++) {
        // Random 6-character codeText (uppercase letters + numbers)
        final String code = List.generate(6, (index) {
          if (rand.nextBool()) {
            return alphabet[rand.nextInt(alphabet.length)];
          } else {
            return rand.nextInt(10).toString();
          }
        }).join();

        // Color and letter
        final Color color = conceptColors[rand.nextInt(conceptColors.length)];
        final String letter = alphabet[rand.nextInt(alphabet.length)];

        _cells.add(
          GridCell(
            id: 'cell_${r}_$c',
            currentCol: c,
            currentRow: r,
            codeText: code,
            color: color,
            secretLetter: letter,
          ),
        );
      }
    }
    notifyListeners();
  }

  // Find a cell at coordinates
  GridCell? getCellAt(int col, int row) {
    try {
      return _cells.firstWhere((cell) => cell.currentCol == col && cell.currentRow == row);
    } catch (_) {
      return null;
    }
  }

  // Swap Cell A and Cell B
  void swapCells(String idA, String idB) {
    if (_isCharacterMode) return; // Locked during character mode
    
    int indexA = _cells.indexWhere((c) => c.id == idA);
    int indexB = _cells.indexWhere((c) => c.id == idB);

    if (indexA != -1 && indexB != -1) {
      final cellA = _cells[indexA];
      final cellB = _cells[indexB];

      // Swap their currentCol and currentRow
      _cells[indexA] = cellA.copyWith(
        currentCol: cellB.currentCol,
        currentRow: cellB.currentRow,
      );
      _cells[indexB] = cellB.copyWith(
        currentCol: cellA.currentCol,
        currentRow: cellA.currentRow,
      );
      
      notifyListeners();
    }
  }

  // Swap Row A and Row B
  void swapRows(int rowA, int rowB) {
    if (_isCharacterMode) return;
    if (rowA == rowB) return;

    for (int col = 0; col < 6; col++) {
      final cellA = getCellAt(col, rowA);
      final cellB = getCellAt(col, rowB);

      if (cellA != null && cellB != null) {
        int indexA = _cells.indexOf(cellA);
        int indexB = _cells.indexOf(cellB);

        _cells[indexA] = cellA.copyWith(currentRow: rowB);
        _cells[indexB] = cellB.copyWith(currentRow: rowA);
      }
    }
    notifyListeners();
  }

  // Swap Column A and Column B
  void swapCols(int colA, int colB) {
    if (_isCharacterMode) return;
    if (colA == colB) return;

    for (int row = 0; row < 8; row++) {
      final cellA = getCellAt(colA, row);
      final cellB = getCellAt(colB, row);

      if (cellA != null && cellB != null) {
        int indexA = _cells.indexOf(cellA);
        int indexB = _cells.indexOf(cellB);

        _cells[indexA] = cellA.copyWith(currentCol: colB);
        _cells[indexB] = cellB.copyWith(currentCol: colA);
      }
    }
    notifyListeners();
  }

  // Handle cell tap
  void handleCellTap(String cellId) {
    if (_isCharacterMode) return;

    if (_selectedCellId == cellId) {
      // Toggle off if tapped again
      _selectedCellId = null;
    } else if (_selectedCellId != null) {
      // Swap with previous selected cell
      swapCells(_selectedCellId!, cellId);
      _selectedCellId = null;
    } else {
      // Select cell and clear handle selection
      _selectedCellId = cellId;
      _selectedRowIndex = null;
      _selectedColIndex = null;
    }
    notifyListeners();
  }

  // Handle row handle tap
  void handleRowTap(int rowIndex) {
    if (_isCharacterMode) return;

    if (_selectedRowIndex == rowIndex) {
      _selectedRowIndex = null;
    } else if (_selectedRowIndex != null) {
      // Swap rows
      swapRows(_selectedRowIndex!, rowIndex);
      _selectedRowIndex = null;
    } else {
      // Select row and clear other selections
      _selectedRowIndex = rowIndex;
      _selectedCellId = null;
      _selectedColIndex = null;
    }
    notifyListeners();
  }

  // Handle col handle tap
  void handleColTap(int colIndex) {
    if (_isCharacterMode) return;

    if (_selectedColIndex == colIndex) {
      _selectedColIndex = null;
    } else if (_selectedColIndex != null) {
      // Swap cols
      swapCols(_selectedColIndex!, colIndex);
      _selectedColIndex = null;
    } else {
      // Select col and clear other selections
      _selectedColIndex = colIndex;
      _selectedCellId = null;
      _selectedRowIndex = null;
    }
    notifyListeners();
  }
}

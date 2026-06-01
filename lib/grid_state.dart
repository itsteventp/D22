import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grid_cell.dart';
import 'map_node.dart';

class GridState extends ChangeNotifier {
  // Screens navigation: 0: Map, 1: Grid
  int _currentScreen = 0;

  // Grid Puzzle state
  List<GridCell> _cells = [];
  int _activeTool = 0; // 0: None, 1-6: Tools

  // Selected cell/handle for Tap-to-Swap
  String? _selectedCellId;
  int? _selectedRowIndex;
  int? _selectedColIndex;

  // Drag state to help with dimming logic
  String? _draggingCellId;
  int? _draggingRowIndex;
  int? _draggingColIndex;

  // Map Screen state
  List<MapNode> _nodes = [];
  List<MapConnection> _connections = [];

  // Master connections list loaded from Supabase
  List<Map<String, dynamic>> _masterConnections = [];

  // Getters
  int get currentScreen => _currentScreen;
  List<GridCell> get cells => _cells;
  int get activeTool => _activeTool;
  bool get isCharacterMode => _activeTool == 6;

  String? get selectedCellId => _selectedCellId;
  int? get selectedRowIndex => _selectedRowIndex;
  int? get selectedColIndex => _selectedColIndex;
  String? get draggingCellId => _draggingCellId;
  int? get draggingRowIndex => _draggingRowIndex;
  int? get draggingColIndex => _draggingColIndex;

  List<String> get cellIds => _cells.map((c) => c.id).toList();

  List<MapNode> get nodes => _nodes;
  List<MapConnection> get connections => _connections;
  List<Map<String, dynamic>> get masterConnections => _masterConnections;

  GridCell getCellById(String id) {
    return _cells.firstWhere((cell) => cell.id == id);
  }

  GridState() {
    generateInitialCells();
    // Start map clean, nodes will be fetched from Supabase
    _nodes = [];
    _connections = [];
  }

  // Navigation setter
  void setScreen(int index) {
    if (index == 0 || index == 1) {
      _currentScreen = index;
      notifyListeners();
    }
  }

  // Query and fetch the master connections list from Supabase
  Future<void> fetchMasterConnections() async {
    try {
      final response = await Supabase.instance.client
          .from('item_connections')
          .select();

      _masterConnections = List<Map<String, dynamic>>.from(response);
      _rebuildConnections();
    } catch (e) {
      if (!e.toString().contains('_isInitialized')) {
        debugPrint('Error fetching master connections: $e');
      }
    }
  }

  // Helper to re-evaluate and draw lines based on current canvas nodes
  void _rebuildConnections() {
    _connections.clear();
    for (final node in _nodes) {
      _checkAndAddConnections(node.id);
    }
    notifyListeners();
  }

  // Expose connections setter for offline unit tests
  void setMasterConnectionsForTesting(List<Map<String, dynamic>> connectionsList) {
    _masterConnections = connectionsList;
    _rebuildConnections();
  }

  // Add node manually for testing connections and layout
  void addNodeForTesting(MapNode node) {
    _nodes.add(node);
    _checkAndAddConnections(node.id);
    notifyListeners();
  }

  // Check connections in both directions and add if both nodes are present
  void _checkAndAddConnections(String nodeId) {
    for (final conn in _masterConnections) {
      final String? fromItem = conn['from_item'];
      final String? toItem = conn['to_item'];

      if (fromItem == null || toItem == null) continue;

      if (fromItem == nodeId || toItem == nodeId) {
        final otherId = fromItem == nodeId ? toItem : fromItem;
        if (_nodes.any((n) => n.id == otherId)) {
          // Check both directions to prevent duplicate links
          final bool alreadyExists = _connections.any((existing) =>
              (existing.fromId == nodeId && existing.toId == otherId) ||
              (existing.fromId == otherId && existing.toId == nodeId));

          if (!alreadyExists) {
            _connections.add(MapConnection(fromId: nodeId, toId: otherId));
          }
        }
      }
    }
  }

  // Update node coordinates during drag
  void updateNodePosition(String id, Offset newOffset) {
    final index = _nodes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _nodes[index] = _nodes[index].copyWith(position: newOffset);
      notifyListeners();
    }
  }

  // Validate entered code against Supabase items table
  Future<void> submitCode(String enteredCode, BuildContext context) async {
    final enteredCodeUpper = enteredCode.toUpperCase().trim();
    if (enteredCodeUpper.isEmpty) return;

    try {
      final response = await Supabase.instance.client
          .from('items')
          .select()
          .eq('code', enteredCodeUpper)
          .maybeSingle();

      if (response == null) {
        // Invalid Code: Clear input and show rose styled SnackBar
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid Code'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFFF43F5E), // rose 500
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Valid Code: Extract fields
      final String itemId = response['item_id'] ?? '';
      final String title = response['title'] ?? '';
      final String concept = response['concept'] ?? '';

      // Check if already mapped
      if (_nodes.any((n) => n.id == itemId)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code already mapped'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF71717A), // zinc 500
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Map concept strings to visual accent colors
      Color conceptColor = Colors.grey;
      switch (concept.toLowerCase()) {
        case 'c1':
          conceptColor = const Color(0xFFAB47BC); // Purple
          break;
        case 'c2':
          conceptColor = const Color(0xFF42A5F5); // Blue
          break;
        case 'c3':
          conceptColor = const Color(0xFF34D399); // Green (emerald 400)
          break;
        case 'c4':
          conceptColor = const Color(0xFFFFA726); // Orange
          break;
        case 'c5':
          conceptColor = const Color(0xFFF43F5E); // Red (rose 400)
          break;
      }

      // Semi-random spawn coordinates within view bounds
      final Random rand = Random();
      final double rx = 50.0 + rand.nextDouble() * 250.0;
      final double ry = 50.0 + rand.nextDouble() * 250.0;

      final newNode = MapNode(
        id: itemId,
        position: Offset(rx, ry),
        color: conceptColor,
        title: title,
      );

      _nodes.add(newNode);

      // Check connections (both directions, no duplicates)
      _checkAndAddConnections(itemId);

      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code mapped: $title'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981), // emerald 500
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating code: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFF43F5E), // rose 500
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Grid Mode Actions
  void setActiveTool(int tool) {
    if (tool >= 0 && tool <= 6) {
      _activeTool = tool;
      clearSelection();
      notifyListeners();
    }
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

  // Generate initial grid state
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
        final String code = List.generate(6, (index) {
          if (rand.nextBool()) {
            return alphabet[rand.nextInt(alphabet.length)];
          } else {
            return rand.nextInt(10).toString();
          }
        }).join();

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
    if (isCharacterMode) return;
    
    int indexA = _cells.indexWhere((c) => c.id == idA);
    int indexB = _cells.indexWhere((c) => c.id == idB);

    if (indexA != -1 && indexB != -1) {
      final cellA = _cells[indexA];
      final cellB = _cells[indexB];

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
    if (isCharacterMode) return;
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
    if (isCharacterMode) return;
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
    if (isCharacterMode) return;

    if (_selectedCellId == cellId) {
      _selectedCellId = null;
    } else if (_selectedCellId != null) {
      swapCells(_selectedCellId!, cellId);
      _selectedCellId = null;
    } else {
      _selectedCellId = cellId;
      _selectedRowIndex = null;
      _selectedColIndex = null;
    }
    notifyListeners();
  }

  // Handle row handle tap
  void handleRowTap(int rowIndex) {
    if (isCharacterMode) return;

    if (_selectedRowIndex == rowIndex) {
      _selectedRowIndex = null;
    } else if (_selectedRowIndex != null) {
      swapRows(_selectedRowIndex!, rowIndex);
      _selectedRowIndex = null;
    } else {
      _selectedRowIndex = rowIndex;
      _selectedCellId = null;
      _selectedColIndex = null;
    }
    notifyListeners();
  }

  // Handle col handle tap
  void handleColTap(int colIndex) {
    if (isCharacterMode) return;

    if (_selectedColIndex == colIndex) {
      _selectedColIndex = null;
    } else if (_selectedColIndex != null) {
      swapCols(_selectedColIndex!, colIndex);
      _selectedColIndex = null;
    } else {
      _selectedColIndex = colIndex;
      _selectedCellId = null;
      _selectedRowIndex = null;
    }
    notifyListeners();
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grid_cell.dart';
import 'map_node.dart';
import 'theme.dart';

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

  // Map Screen — blob nodes
  List<MapNode> _nodes = [];
  List<MapConnection> _connections = [];

  // Master connections list loaded from Supabase
  List<Map<String, dynamic>> _masterConnections = [];

  // Pentagram ending state
  final Set<String> _activeEndings = {};
  final List<String> _unlockOrder = []; // concepts in order of discovery

  // ── Performance: cache validated items to avoid repeated DB round-trips ──────
  final Map<String, Map<String, dynamic>> _itemsCache = {};
  bool _masterConnectionsFetched = false;

  // ── Local session tracking (dev mode — not written to unlocked_codes) ────────
  final List<Map<String, dynamic>> _localUnlockedCodes = [];

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

  // Ending / pentagram getters
  bool isEndingActive(String concept) => _activeEndings.contains(concept);
  Set<String> get activeEndingSet => Set.unmodifiable(_activeEndings);
  List<String> get unlockOrder => List.unmodifiable(_unlockOrder);
  bool get allEndingsUnlocked => _unlockOrder.length == 5;

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

  // ---------------------------------------------------------------------------
  // Ending state management
  // ---------------------------------------------------------------------------

  /// Activates a pentagram ending node by concept ID ('c1'–'c5').
  void activateEnding(String concept) {
    if (_activeEndings.contains(concept)) return;
    _activeEndings.add(concept);
    _unlockOrder.add(concept);
    notifyListeners();
  }

  /// DEV-ONLY: instantly activate all 5 endings in a random order.
  void devAutoComplete() {
    const concepts = ['c1', 'c2', 'c3', 'c4', 'c5'];
    final remaining = concepts.where((c) => !_activeEndings.contains(c)).toList()
      ..shuffle();
    for (final c in remaining) {
      _activeEndings.add(c);
      _unlockOrder.add(c);
    }
    notifyListeners();
  }

  // Query and fetch the master connections list from Supabase.
  // Guarded — skips the network call if data is already loaded.
  Future<void> fetchMasterConnections() async {
    if (_masterConnectionsFetched) return;
    try {
      final response = await Supabase.instance.client
          .from('item_connections')
          .select();

      _masterConnectionsFetched = true;
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
        if (context.mounted) {
          _showToast(context, 'Invalid code', AppColors.error);
        }
        return;
      }

      // Valid Code: Extract fields
      final String itemId = response['item_id'] ?? '';
      final String title  = response['title']   ?? '';
      final String concept = response['concept'] ?? '';

      // Map concept to accent color (used for both endings and blobs)
      Color conceptColor = AppColors.textMuted;
      switch (concept.toLowerCase()) {
        case 'c1': conceptColor = AppColors.conceptPurple; break;
        case 'c2': conceptColor = AppColors.conceptBlue;   break;
        case 'c3': conceptColor = AppColors.conceptTeal;   break;
        case 'c4': conceptColor = AppColors.conceptOrange; break;
        case 'c5': conceptColor = AppColors.conceptRose;   break;
      }

      // ── Ending path: activate pentagram node, skip blob spawn ─────────────
      final bool isEnding = response['is_ending'] == true;
      if (isEnding) {
        if (_activeEndings.contains(concept)) {
          if (context.mounted) {
            _showToast(context, 'Ending already discovered', AppColors.textMuted);
          }
          return;
        }
        activateEnding(concept);
        if (context.mounted) {
          _showToast(context, 'Ending discovered: $title', conceptColor);
        }
        return;
      }

      // ── Regular item path: spawn as floating blob ─────────────────────────
      if (_nodes.any((n) => n.id == itemId)) {
        if (context.mounted) {
          _showToast(context, 'Already mapped: $title', AppColors.textMuted);
        }
        return;
      }

      // Semi-random spawn near canvas center
      final Random rand = Random();
      final double rx = 120.0 + rand.nextDouble() * 300.0;
      final double ry = 100.0 + rand.nextDouble() * 220.0;

      final newNode = MapNode(
        id: itemId,
        position: Offset(rx, ry),
        color: conceptColor,
        title: title,
      );

      _nodes.add(newNode);
      _checkAndAddConnections(itemId);
      notifyListeners();

      if (context.mounted) {
        _showToast(context, 'Mapped: $title', AppColors.success);
      }

    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Error: $e', AppColors.error);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // submitCodeWithImage — validates code (with in-memory cache), stores entry
  // locally. Image path comes from the Storage upload done in the UI layer.
  // Dev mode: does NOT write to the unlocked_codes table.
  // ---------------------------------------------------------------------------
  Future<void> submitCodeWithImage(
    String enteredCode,
    String imagePath,
    BuildContext context,
  ) async {
    final upper = enteredCode.toUpperCase().trim();
    if (upper.isEmpty) return;

    // Try in-memory cache first — zero DB cost on repeat lookups
    Map<String, dynamic>? item = _itemsCache[upper];
    if (item == null) {
      try {
        final response = await Supabase.instance.client
            .from('items')
            .select()
            .eq('code', upper)
            .maybeSingle();

        if (response == null) {
          if (context.mounted) {
            _showToast(context, 'Invalid code', AppColors.error);
          }
          return;
        }
        _itemsCache[upper] = Map<String, dynamic>.from(response);
        item = _itemsCache[upper]!;
      } catch (e) {
        if (context.mounted) {
          _showToast(context, 'Error: $e', AppColors.error);
        }
        return;
      }
    }

    final String itemId  = item['item_id'] ?? '';
    final String title   = item['title']   ?? '';
    final String concept = item['concept'] ?? '';
    final bool isEnding  = item['is_ending'] == true;

    Color conceptColor = AppColors.textMuted;
    switch (concept.toLowerCase()) {
      case 'c1': conceptColor = AppColors.conceptPurple; break;
      case 'c2': conceptColor = AppColors.conceptBlue;   break;
      case 'c3': conceptColor = AppColors.conceptTeal;   break;
      case 'c4': conceptColor = AppColors.conceptOrange; break;
      case 'c5': conceptColor = AppColors.conceptRose;   break;
    }

    // ── Ending path ───────────────────────────────────────────────────────────
    if (isEnding) {
      if (_activeEndings.contains(concept)) {
        if (context.mounted) {
          _showToast(context, 'Ending already discovered', AppColors.textMuted);
        }
        return;
      }
      activateEnding(concept);
      _localUnlockedCodes.add({
        'item_id': itemId,
        'unlocked_at': DateTime.now().toIso8601String(),
        'image_path': imagePath,
      });
      if (context.mounted) {
        _showToast(context, 'Ending discovered: $title', conceptColor);
      }
      return;
    }

    // ── Regular item: spawn as floating blob ──────────────────────────────────
    if (_nodes.any((n) => n.id == itemId)) {
      if (context.mounted) {
        _showToast(context, 'Already mapped: $title', AppColors.textMuted);
      }
      return;
    }

    final Random rand = Random();
    _nodes.add(MapNode(
      id: itemId,
      position: Offset(
        120.0 + rand.nextDouble() * 300.0,
        100.0 + rand.nextDouble() * 220.0,
      ),
      color: conceptColor,
      title: title,
    ));
    _checkAndAddConnections(itemId);
    _localUnlockedCodes.add({
      'item_id': itemId,
      'unlocked_at': DateTime.now().toIso8601String(),
      'image_path': imagePath,
    });
    notifyListeners();

    if (context.mounted) {
      _showToast(context, 'Mapped: $title', AppColors.success);
    }
  }

  // ---------------------------------------------------------------------------
  // Floating toast helper
  // ---------------------------------------------------------------------------
  void _showToast(BuildContext context, String message, Color accentColor) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C24),
            borderRadius: BorderRadius.circular(12.0),
            border: Border(
              left: BorderSide(color: accentColor, width: 3.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: Color(0xFFEEEEF5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        duration: const Duration(seconds: 2),
        padding: EdgeInsets.zero,
      ),
    );
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

  // ---------------------------------------------------------------------------
  // fetchAllImagePaths — lists all uploaded images from Supabase Storage.
  // Returns public URLs ready for Image.network.
  // ---------------------------------------------------------------------------
  Future<List<String>> fetchAllImagePaths() async {
    try {
      final files = await Supabase.instance.client.storage
          .from('unlocked_images')
          .list();

      return files
          .where((f) => f.name.isNotEmpty && !f.name.startsWith('.'))
          .map((f) => Supabase.instance.client.storage
              .from('unlocked_images')
              .getPublicUrl(f.name))
          .toList();
    } catch (e) {
      debugPrint('Error fetching image paths: $e');
      return [];
    }
  }
}

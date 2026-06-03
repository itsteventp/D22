import 'dart:async' show Timer;
import 'dart:convert' show jsonEncode, jsonDecode;
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grid_cell.dart';
import 'map_node.dart';
import 'theme.dart';

class GridState extends ChangeNotifier {
  static const Set<String> _endingCodes = {
    'DDD1D2',
    '1CLMF1',
    '5FY414',
    'HLM832',
    '7C7DM1',
  };

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

  // Chronological unlocked items
  List<String> _chronologicalUnlockedItemIds = [];

  // Progressive loading animation state
  int _revealedCount = 0;
  bool _isProgressiveLoading = false;

  int get revealedCount => _revealedCount;
  bool get isProgressiveLoading => _isProgressiveLoading;

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

  // ── Authentication & persistence state ─────────────────────────────────────
  bool _isLoggedIn = false;
  bool _isLoggingIn = false;
  DateTime? _startDate;

  // ── Finalization / completion state ────────────────────────────────────────
  bool _isFinalizing = false;
  double _finalizationProgress = 0.0;
  bool _isSolvedAndFinished = false;

  // Getters
  int get currentScreen => _currentScreen;
  List<GridCell> get cells => _cells;
  int get activeTool => _activeTool;
  bool get isCharacterMode => _activeTool == 6;
  bool get isFinalizing => _isFinalizing;
  double get finalizationProgress => _finalizationProgress;
  bool get isSolvedAndFinished => _isSolvedAndFinished;

  bool get isDevMode {
    try {
      final href = html.window.location.href.toLowerCase();
      return href.contains('dev=true') || href.contains('dev?true');
    } catch (_) {
      return false;
    }
  }

  String? get selectedCellId => _selectedCellId;
  int? get selectedRowIndex => _selectedRowIndex;
  int? get selectedColIndex => _selectedColIndex;
  String? get draggingCellId => _draggingCellId;
  int? get draggingRowIndex => _draggingRowIndex;
  String? get draggingColId => _draggingCellId; // legacy support
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

  int get unlockedCluesCount {
    if (isDevMode) return 5;
    if (_startDate == null) return 0;
    final diff = DateTime.now().difference(_startDate!);
    final days = diff.inHours ~/ 24;
    return days.clamp(0, 5);
  }

  bool isClueUnlocked(String concept) {
    if (isDevMode) return true;
    if (!allEndingsUnlocked) return false;
    final count = unlockedCluesCount;
    final idx = _unlockOrder.indexOf(concept);
    if (idx == -1) return false;
    return idx < count;
  }

  // Auth / session getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoggingIn => _isLoggingIn;
  DateTime? get startDate => _startDate;

  GridCell getCellById(String id) {
    return _cells.firstWhere((cell) => cell.id == id);
  }

  GridState() {
    // Check if user is already logged in
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _isLoggedIn = true;
      loadStateFromSupabase();
    } else {
      generateInitialCells();
      _nodes = [];
      _connections = [];
    }
  }

  // ---------------------------------------------------------------------------
  // Authentication & Supabase state synchronization
  // ---------------------------------------------------------------------------

  Future<bool> login(String password) async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: 'amorde@mivida.com',
        password: password,
      );
      if (response.session != null) {
        _isLoggedIn = true;
        _isLoggingIn = false;
        await loadStateFromSupabase();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login failed: $e');
    }
    _isLoggingIn = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _isLoggedIn = false;
    _startDate = null;
    _activeEndings.clear();
    _unlockOrder.clear();
    _nodes.clear();
    _connections.clear();
    _cells.clear();
    _itemsCache.clear();
    html.window.localStorage.remove('grid_layout');
    html.window.localStorage.remove('active_tool');
    html.window.localStorage.remove('start_date');
    generateInitialCells();
    notifyListeners();
  }

  Future<void> loadStateFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch all items to populate cache
      final itemsResponse = await Supabase.instance.client.from('items').select();
      _itemsCache.clear();
      for (final item in itemsResponse) {
        _itemsCache[item['code'].toString().toUpperCase()] = Map<String, dynamic>.from(item);
      }

      // 2. Fetch master connections
      await fetchMasterConnections();

      // 3. Fetch unlocked codes for this user
      final unlockedResponse = await Supabase.instance.client
          .from('unlocked_codes')
          .select()
          .eq('user_id', user.id);

      final unlockedList = List<Map<String, dynamic>>.from(unlockedResponse);
      unlockedList.sort((a, b) {
        final aTime = DateTime.tryParse(a['unlocked_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = DateTime.tryParse(b['unlocked_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
      _chronologicalUnlockedItemIds = unlockedList.map((u) => u['item_id'].toString()).toList();

      _nodes.clear();
      _activeEndings.clear();
      _unlockOrder.clear();

      for (final unlock in unlockedList) {
        final itemId = unlock['item_id'];

        final item = _itemsCache.values.firstWhere(
          (i) => i['item_id'] == itemId,
          orElse: () => {},
        );

        if (item.isEmpty) continue;

        final concept = item['concept'] ?? '';
        final String title = item['title'] ?? '';
        final bool isEnding = _endingCodes.contains(item['code']?.toString().toUpperCase() ?? '');

        Color conceptColor = AppColors.textMuted;
        switch (concept.toLowerCase()) {
          case 'c1': conceptColor = AppColors.conceptPurple; break;
          case 'c2': conceptColor = AppColors.conceptBlue;   break;
          case 'c3': conceptColor = AppColors.conceptTeal;   break;
          case 'c4': conceptColor = AppColors.conceptOrange; break;
          case 'c5': conceptColor = AppColors.conceptRose;   break;
        }

        if (isEnding) {
          _activeEndings.add(concept);
          _unlockOrder.add(concept);
        } else {
          final Random rand = Random();
          _nodes.add(MapNode(
            id: itemId,
            position: Offset(
              120.0 + rand.nextDouble() * 300.0,
              160.0 + rand.nextDouble() * 180.0,
            ),
            color: conceptColor,
            title: title,
          ));
        }
      }

      _rebuildConnections();

      // 4. Fetch game state
      final gameStateResponse = await Supabase.instance.client
          .from('game_state')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (gameStateResponse != null) {
        final List<dynamic> layout = gameStateResponse['grid_layout'];
        _cells = layout.map((json) => GridCell.fromJson(json as Map<String, dynamic>)).toList();
        _activeTool = gameStateResponse['active_tool'] ?? 0;
        if (gameStateResponse['start_date'] != null) {
          _startDate = DateTime.parse(gameStateResponse['start_date']);
        }
      } else {
        // Fallback to local storage or clean init
        final localLayout = html.window.localStorage['grid_layout'];
        final localTool = html.window.localStorage['active_tool'];
        final localStart = html.window.localStorage['start_date'];

        if (localLayout != null) {
          final List<dynamic> layout = jsonDecode(localLayout);
          _cells = layout.map((json) => GridCell.fromJson(json as Map<String, dynamic>)).toList();
          _activeTool = localTool != null ? int.tryParse(localTool) ?? 0 : 0;
          if (localStart != null) {
            _startDate = DateTime.tryParse(localStart);
          }
        } else {
          generateInitialCells();
        }

        await syncGameStateToSupabase();
      }

      if (allEndingsUnlocked && _startDate == null) {
        _startDate = DateTime.now();
        await syncGameStateToSupabase();
      }

      if (isGridSolved) {
        _isSolvedAndFinished = true;
        _isFinalizing = true;
        _finalizationProgress = 1.0;
      } else {
        final localSolved = html.window.localStorage['is_solved_and_finished'];
        if (localSolved == 'true') {
          _isSolvedAndFinished = true;
          _isFinalizing = true;
          _finalizationProgress = 1.0;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading state from Supabase: $e');
    }
  }

  Future<void> syncGameStateToSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final gridJson = _cells.map((c) => c.toJson()).toList();

    // 1. Local storage sync
    html.window.localStorage['grid_layout'] = jsonEncode(gridJson);
    html.window.localStorage['active_tool'] = _activeTool.toString();
    if (_startDate != null) {
      html.window.localStorage['start_date'] = _startDate!.toIso8601String();
    }

    // 2. Supabase async sync
    Supabase.instance.client.from('game_state').upsert({
      'user_id': user.id,
      'grid_layout': gridJson,
      'active_tool': _activeTool,
      if (_startDate != null) 'start_date': _startDate!.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).then((_) {
      debugPrint('Synced game state to Supabase.');
    }).catchError((e) {
      debugPrint('Error syncing game state: $e');
    });
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
    _rebuildConnections();
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
    _rebuildConnections();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Dev Actions
  // ---------------------------------------------------------------------------

  Future<void> eraseAllData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('unlocked_codes').delete().eq('user_id', user.id);
      await Supabase.instance.client.from('game_state').delete().eq('user_id', user.id);
      
      _activeEndings.clear();
      _unlockOrder.clear();
      _nodes.clear();
      _connections.clear();
      _chronologicalUnlockedItemIds.clear();
      _startDate = null;
      generateInitialCells();
      _currentScreen = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error erasing data: $e');
    }
  }

  Future<void> loadAllData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final List<Map<String, dynamic>> inserts = [];
      for (final item in _itemsCache.values) {
        inserts.add({
          'user_id': user.id,
          'item_id': item['item_id'],
          'image_path': '',
        });
      }
      await Supabase.instance.client.from('unlocked_codes').upsert(inserts, onConflict: 'user_id,item_id');
      await loadStateFromSupabase();
    } catch (e) {
      debugPrint('Error loading all data: $e');
    }
  }

  void deleteGridCodes() {
    _cells = _cells.map((cell) => cell.copyWith(
      codeText: '',
      color: Colors.transparent,
      secretLetter: '',
    )).toList();
    _revealedCount = 0;
    notifyListeners();
    syncGameStateToSupabase();
  }

  void startProgressiveLoad() {
    _revealedCount = 0;
    _isProgressiveLoading = true;
    
    final List<GridCell> newCells = [];
    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final Random rand = Random();
    
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 6; c++) {
        final int index = r * 6 + c;
        String code = '';
        Color color = AppColors.surfaceHigh;
        String letter = alphabet[rand.nextInt(alphabet.length)];
        
        if (index < _chronologicalUnlockedItemIds.length) {
          final itemId = _chronologicalUnlockedItemIds[index];
          final item = _itemsCache.values.firstWhere(
            (i) => i['item_id'] == itemId,
            orElse: () => {},
          );
          if (item.isNotEmpty) {
            code = item['code'] ?? '';
            final concept = item['concept'] ?? '';
            letter = item['secret_letter'] ?? '';
            
            switch (concept.toLowerCase()) {
              case 'c1': color = AppColors.conceptPurple; break;
              case 'c2': color = AppColors.conceptBlue;   break;
              case 'c3': color = AppColors.conceptTeal;   break;
              case 'c4': color = AppColors.conceptOrange; break;
              case 'c5': color = AppColors.conceptRose;   break;
            }
          }
        }
        
        newCells.add(GridCell(
          id: 'cell_${r}_$c',
          currentCol: c,
          currentRow: r,
          codeText: code,
          color: color,
          secretLetter: letter,
        ));
      }
    }
    
    _cells = newCells;
    notifyListeners();
    
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isProgressiveLoading) {
        timer.cancel();
        return;
      }
      _revealedCount++;
      if (_revealedCount >= 48) {
        _isProgressiveLoading = false;
        timer.cancel();
        syncGameStateToSupabase();
      }
      notifyListeners();
    });
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

  bool _isItemActive(String itemId) {
    if (_nodes.any((n) => n.id == itemId)) return true;
    final item = _itemsCache.values.firstWhere(
      (i) => i['item_id'] == itemId,
      orElse: () => {},
    );
    if (item.isNotEmpty) {
      final String concept = item['concept'] ?? '';
      final String code = item['code']?.toString().toUpperCase() ?? '';
      if (_endingCodes.contains(code)) {
        return _activeEndings.contains(concept);
      }
    }
    return false;
  }

  // Check connections in both directions and add if both nodes are present
  void _checkAndAddConnections(String nodeId) {
    for (final conn in _masterConnections) {
      final String? fromItem = conn['from_item'];
      final String? toItem = conn['to_item'];

      if (fromItem == null || toItem == null) continue;

      if (fromItem == nodeId || toItem == nodeId) {
        final otherId = fromItem == nodeId ? toItem : fromItem;
        if (_isItemActive(otherId)) {
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

      if (!_chronologicalUnlockedItemIds.contains(itemId)) {
        _chronologicalUnlockedItemIds.add(itemId);
      }
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
      final bool isEnding = _endingCodes.contains(response['code']?.toString().toUpperCase() ?? '');
      if (isEnding) {
        if (_activeEndings.contains(concept)) {
          if (context.mounted) {
            _showToast(context, 'Ending already discovered', AppColors.textMuted);
          }
          return;
        }
        activateEnding(concept);
        if (_unlockOrder.length == 5 && _startDate == null) {
          _startDate = DateTime.now();
          await syncGameStateToSupabase();
        }
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
      final double ry = 160.0 + rand.nextDouble() * 180.0;

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

    // Try in-memory cache first
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

    if (!_chronologicalUnlockedItemIds.contains(itemId)) {
      _chronologicalUnlockedItemIds.add(itemId);
    }
    final String concept = item['concept'] ?? '';
    final bool isEnding  = _endingCodes.contains(item['code']?.toString().toUpperCase() ?? '');

    Color conceptColor = AppColors.textMuted;
    switch (concept.toLowerCase()) {
      case 'c1': conceptColor = AppColors.conceptPurple; break;
      case 'c2': conceptColor = AppColors.conceptBlue;   break;
      case 'c3': conceptColor = AppColors.conceptTeal;   break;
      case 'c4': conceptColor = AppColors.conceptOrange; break;
      case 'c5': conceptColor = AppColors.conceptRose;   break;
    }

    final user = Supabase.instance.client.auth.currentUser;
    final bool alreadyUnlocked = isEnding 
        ? _activeEndings.contains(concept) 
        : _nodes.any((n) => n.id == itemId);

    if (alreadyUnlocked) {
      if (context.mounted) {
        _showToast(
          context,
          isEnding ? 'Ending already discovered' : 'Already mapped: $title',
          AppColors.textMuted,
        );
      }
      return;
    }

    // Write to Supabase (asynchronously)
    if (user != null) {
      Supabase.instance.client.from('unlocked_codes').insert({
        'user_id': user.id,
        'item_id': itemId,
        'image_path': imagePath,
      }).then((_) {
        debugPrint('Synced unlocked code $itemId to Supabase.');
      }).catchError((e) {
        debugPrint('Error syncing unlocked code: $e');
      });
    }

    // ── Ending path ───────────────────────────────────────────────────────────
    if (isEnding) {
      activateEnding(concept);
      _localUnlockedCodes.add({
        'item_id': itemId,
        'unlocked_at': DateTime.now().toIso8601String(),
        'image_path': imagePath,
      });

      if (_unlockOrder.length == 5 && _startDate == null) {
        _startDate = DateTime.now();
        await syncGameStateToSupabase();
      }

      if (context.mounted) {
        _showToast(context, 'Ending discovered: $title', conceptColor);
      }
      return;
    }

    // ── Regular item: spawn as floating blob ──────────────────────────────────
    final Random rand = Random();
    _nodes.add(MapNode(
      id: itemId,
      position: Offset(
        120.0 + rand.nextDouble() * 300.0,
        160.0 + rand.nextDouble() * 180.0,
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
      if (tool >= 1 && tool <= 5) {
        final concept = 'c$tool';
        if (!isClueUnlocked(concept)) return;
      }
      _activeTool = tool;
      clearSelection();
      notifyListeners();
      syncGameStateToSupabase();
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

  // Final target configuration of codes
  static const List<List<String>> kCorrectGrid = [
    ['1CLMF1', 'Z82012', 'M2IM62', 'B02DT2', 'B17A41', '2WAPPF'],
    ['4T9F82', 'RA4YR1', '8F4MQK', 'K123S1', 'D655J1', 'JB4UG2'],
    ['V97JCA', 'AW3Z8Q', '9BC8E2', '375BPG', 'TZ1P02', '635R92'],
    ['K57E72', 'K8TD91', '1FMLC1', 'FPPAW2', '32CK42', '3G8D83'],
    ['F83N71', 'V3I2K2', 'GFAN63', 'A0XH0A', '896X9C', '7C7DM1'],
    ['ABCA43', '00I1A1', '5FY414', 'XECY72', '0CRL51', 'HLM832'],
    ['1BRB61', 'DDD1D2', 'IB6001', 'B39BU2', 'FJSM91', 'D6A371'],
    ['36NAFG', '6IITU1', '8I27J3', 'B48EF1', '07617G', 'A0HX0A'],
  ];

  // Check if grid is solved
  bool get isGridSolved {
    if (_cells.length < 48) return false;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 6; c++) {
        final cell = getCellAt(c, r);
        if (cell == null || cell.codeText != kCorrectGrid[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  void checkGrid(BuildContext context) {
    if (isGridSolved) {
      _showToast(context, 'Stabilization complete.', AppColors.success);
    } else {
      _showToast(context, 'Verification failed.', AppColors.error);
    }
  }

  // Generate initial grid state by scrambling the final codes
  void generateInitialCells() {
    scrambleGrid(syncToSupabase: false);
  }

  // Scramble the correct codes and assign to grid
  void scrambleGrid({bool syncToSupabase = true}) {
    final List<String> flatCodes = [];
    for (final row in kCorrectGrid) {
      flatCodes.addAll(row);
    }
    flatCodes.shuffle();

    final List<Color> conceptColors = [
      AppColors.conceptPurple,
      AppColors.conceptBlue,
      AppColors.conceptTeal,
      AppColors.conceptOrange,
      AppColors.conceptRose,
    ];

    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final Random rand = Random();

    _cells = [];
    int index = 0;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 6; c++) {
        final String code = flatCodes[index++];
        final Color color = conceptColors[rand.nextInt(conceptColors.length)];
        final item = _itemsCache[code.toUpperCase()];
        final String letter = item != null
            ? (item['secret_letter'] ?? '')
            : alphabet[rand.nextInt(alphabet.length)];

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
    if (syncToSupabase && isLoggedIn) {
      syncGameStateToSupabase();
    }
  }

  // ── Finalization helper methods ──────────────────────────────────────────
  
  void startFinalization() {
    _isFinalizing = true;
    _finalizationProgress = 0.0;
    // Make sure cells have their correct secret letters from items cache
    for (int i = 0; i < _cells.length; i++) {
      final cell = _cells[i];
      final item = _itemsCache[cell.codeText.toUpperCase()];
      if (item != null) {
        final secretLetter = item['secret_letter'] ?? '';
        _cells[i] = cell.copyWith(secretLetter: secretLetter);
      }
    }
    notifyListeners();
  }

  void updateFinalizationProgress(double progress) {
    if (_isFinalizing) {
      _finalizationProgress = progress;
      notifyListeners();
    }
  }

  void cancelFinalization() {
    _isFinalizing = false;
    _finalizationProgress = 0.0;
    notifyListeners();
  }

  void completePuzzle() {
    _isSolvedAndFinished = true;
    _isFinalizing = true;
    _finalizationProgress = 1.0;
    html.window.localStorage['is_solved_and_finished'] = 'true';
    notifyListeners();
  }

  void resetCompletion() {
    html.window.localStorage.remove('is_solved_and_finished');
    _isSolvedAndFinished = false;
    _isFinalizing = false;
    _finalizationProgress = 0.0;
    scrambleGrid();
  }

  void solveGrid() {
    final List<Color> conceptColors = [
      AppColors.conceptPurple,
      AppColors.conceptBlue,
      AppColors.conceptTeal,
      AppColors.conceptOrange,
      AppColors.conceptRose,
    ];
    final Random rand = Random();

    _cells = [];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 6; c++) {
        final code = kCorrectGrid[r][c];
        final color = conceptColors[rand.nextInt(conceptColors.length)];
        final item = _itemsCache[code.toUpperCase()];
        final letter = item != null ? (item['secret_letter'] ?? '') : 'A';

        _cells.add(GridCell(
          id: 'cell_${r}_$c',
          currentCol: c,
          currentRow: r,
          codeText: code,
          color: color,
          secretLetter: letter,
        ));
      }
    }
    _isSolvedAndFinished = false;
    _isFinalizing = false;
    _finalizationProgress = 0.0;
    notifyListeners();
    syncGameStateToSupabase();
  }

  Offset getFinalMessagePosition(int slotIndex, double boardWidth) {
    int lineIndex;
    int blockIndex;
    int charIndexInBlock;

    final List<int> line1Blocks = [5, 6, 2, 4];
    final List<int> line2Blocks = [5, 1, 2, 4, 7];
    final List<int> line3Blocks = [4, 8];

    if (slotIndex >= 0 && slotIndex <= 16) {
      lineIndex = 0;
      int rem = slotIndex;
      blockIndex = 0;
      for (int i = 0; i < line1Blocks.length; i++) {
        if (rem < line1Blocks[i]) {
          blockIndex = i;
          break;
        }
        rem -= line1Blocks[i];
      }
      charIndexInBlock = rem;
    } else if (slotIndex >= 17 && slotIndex <= 35) {
      lineIndex = 1;
      int rem = slotIndex - 17;
      blockIndex = 0;
      for (int i = 0; i < line2Blocks.length; i++) {
        if (rem < line2Blocks[i]) {
          blockIndex = i;
          break;
        }
        rem -= line2Blocks[i];
      }
      charIndexInBlock = rem;
    } else if (slotIndex >= 36 && slotIndex <= 47) {
      lineIndex = 2;
      int rem = slotIndex - 36;
      blockIndex = 0;
      for (int i = 0; i < line3Blocks.length; i++) {
        if (rem < line3Blocks[i]) {
          blockIndex = i;
          break;
        }
        rem -= line3Blocks[i];
      }
      charIndexInBlock = rem;
    } else {
      return Offset(boardWidth / 2 - 24.0, 200.0);
    }

    final List<int> currentLineBlocks = lineIndex == 0
        ? line1Blocks
        : (lineIndex == 1 ? line2Blocks : line3Blocks);

    const double charWidth = 12.0;
    const double charSpacing = 1.0;
    const double wordSpacing = 10.0;

    double totalWidth = 0.0;
    for (int i = 0; i < currentLineBlocks.length; i++) {
      final len = currentLineBlocks[i];
      totalWidth += len * charWidth + (len - 1) * charSpacing;
      if (i < currentLineBlocks.length - 1) {
        totalWidth += wordSpacing;
      }
    }

    final startX = (boardWidth - totalWidth) / 2;

    double precedingWidth = 0.0;
    for (int i = 0; i < blockIndex; i++) {
      final len = currentLineBlocks[i];
      precedingWidth += len * charWidth + (len - 1) * charSpacing + wordSpacing;
    }

    // Adjust by -(cellWidth/2 - charWidth/2) so that the cell's center aligns with the character's centered layout position.
    final x = startX + precedingWidth + charIndexInBlock * (charWidth + charSpacing) - (24.0 - charWidth / 2);
    final double y = 80.0 + lineIndex * 50.0;

    return Offset(x, y);
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
      syncGameStateToSupabase();
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
    syncGameStateToSupabase();
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
    syncGameStateToSupabase();
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

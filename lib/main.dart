import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grid_state.dart';
import 'map_screen.dart';
import 'puzzle_board.dart';
import 'theme.dart';
import 'widgets/pentagram_painter.dart';
import 'widgets/morphing_input_bar.dart';
import 'widgets/void_background_painter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pvsnqcnpunhuxquhlcld.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2c25xY25wdW5odXhxdWhsY2xkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNzkwMDksImV4cCI6MjA5NTg1NTAwOX0.kflbafAlRmpLEhAEU2isJKSJATtsMeAQ9ZUvWCnubFU',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => GridState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARG Decryptor System',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const MainNavigator(),
    );
  }
}

// ---------------------------------------------------------------------------
// MainNavigator — owns the transition animation and the persistent pentagram.
//
// Layout model:
//   Stack ─────────────────────────────────────────────────
//   │  [0] MapScreen      full-size, fades to 0 as t → 1
//   │  [1] PuzzleBoard    slides up from below as t → 1
//   │  [2] PentagramOverlay  animated center/radius; always on top
//   │  [3] Dev FAB        always accessible for testing
//   ────────────────────────────────────────────────────────
//
// t = _transAnim.value: 0.0 = Map view (pentagram centered)
//                       1.0 = Grid view (pentagram at top)
// ---------------------------------------------------------------------------
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator>
    with TickerProviderStateMixin {
  // ── Transition (map ↔ grid) ────────────────────────────────────────────────
  late final AnimationController _transCtrl;
  late final CurvedAnimation _transAnim;

  // ── Thread-draw animation (fires once when all 5 endings unlocked) ─────────
  late final AnimationController _threadCtrl;
  bool _threadTriggered = false;

  // ── Login transition ───────────────────────────────────────────────────────
  late final AnimationController _loginCtrl;
  late final CurvedAnimation _loginAnim;

  // ── Shake animation (on login failure) ────────────────────────────────────
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  // ── Elapsed time → core pulse ──────────────────────────────────────────────
  late final Ticker _elapsedTicker;
  final ValueNotifier<double> _elapsedNotifier = ValueNotifier(0.0);
  double _elapsed = 0.0;
  DateTime _lastElapsedTick = DateTime.now();

  // ── Pentagram hover state (triggers setState, not every frame) ─────────────
  String? _hoveredPentagramId;

  // ── Canvas size (captured once from LayoutBuilder) ─────────────────────────
  Size _screenSize = const Size(800, 600);

  // ── Pentagram geometry constants ───────────────────────────────────────────
  //   Map mode:  node radius 18 px, layout radius up to 165 px
  //   Grid mode: node radius 10 px, layout radius 50 px (compact header)
  static const double _gridHeaderH   = 158.0; // pixels reserved for mini pentagram
  static const double _gridCenterY   = 78.0;  // center Y of mini pentagram
  static const double _gridLayoutR   = 50.0;
  static const double _mapNodeR      = 18.0;
  static const double _gridNodeR     = 10.0;
  static const double _mapCoreR      = 12.0;
  static const double _gridCoreR     = 7.0;
  static const double _inputBarH     = 66.0;  // approximate height of MapScreen input bar

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();

    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _transAnim = CurvedAnimation(
      parent: _transCtrl,
      curve: Curves.easeInOutCubic,
    );

    _threadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _loginCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _loginAnim = CurvedAnimation(
      parent: _loginCtrl,
      curve: Curves.easeInOutCubic,
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _elapsedTicker = createTicker(_onElapsedTick)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = Provider.of<GridState>(context, listen: false);
      state.addListener(_onStateChanged);

      // Handle already-complete state on cold start
      if (state.allEndingsUnlocked) {
        _threadTriggered = true;
        _threadCtrl.value = 1.0;
      }

      // Handle already-logged in state on cold start
      if (state.isLoggedIn) {
        _loginCtrl.value = 1.0;
      }
    });
  }

  void _onElapsedTick(Duration _) {
    final now = DateTime.now();
    final dt =
        (now.difference(_lastElapsedTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastElapsedTick = now;
    _elapsed += dt;
    _elapsedNotifier.value = _elapsed;
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = Provider.of<GridState>(context, listen: false);

    // Thread animation: play once when all five endings are first discovered
    if (state.allEndingsUnlocked && !_threadTriggered) {
      _threadTriggered = true;
      _threadCtrl.forward(from: 0.0);
    }

    // Drive the transition based on GridState.currentScreen
    final screen = state.currentScreen;
    if (screen == 1) {
      _transCtrl.forward();
    } else {
      _transCtrl.reverse();
    }
  }

  @override
  void dispose() {
    try {
      Provider.of<GridState>(context, listen: false)
          .removeListener(_onStateChanged);
    } catch (_) {}
    _transCtrl.dispose();
    _threadCtrl.dispose();
    _loginCtrl.dispose();
    _shakeCtrl.dispose();
    _elapsedTicker.dispose();
    _elapsedNotifier.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Pentagram geometry helpers
  // ══════════════════════════════════════════════════════════════════════════

  /// Center of the pentagram when displaying the Map view.
  Offset _mapCenter(Size s) =>
      Offset(s.width / 2, (_inputBarH + s.height) / 2);

  /// Center of the pentagram when displayed as a grid header strip.
  Offset _gridCenter(Size s) => Offset(s.width / 2, _gridCenterY);

  /// Layout radius (center → vertex) in Map mode, clamped for small screens.
  double _mapRadius(Size s) => (s.shortestSide * 0.28).clamp(90.0, 165.0);

  /// Compute the 5 vertex positions for the given center and radius.
  Map<String, Offset> _computeConceptPositions(Offset center, double radius) {
    const concepts = ['c1', 'c2', 'c3', 'c4', 'c5'];
    return {
      for (var i = 0; i < 5; i++)
        concepts[i]: Offset(
          center.dx + cos(-pi / 2 + i * 2 * pi / 5) * radius,
          center.dy + sin(-pi / 2 + i * 2 * pi / 5) * radius,
        )
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            _screenSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            final s = _screenSize;

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // ── Layer 0: Void Background (always on bottom) ──────────────
                Positioned.fill(
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: const VoidBackgroundPainter(),
                    ),
                  ),
                ),

                // ── Layer 1: MapScreen — fades in with login, out with trans ─
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_loginAnim, _transAnim]),
                    builder: (ctx, child) {
                      final tLogin = _loginAnim.value;
                      final tTrans = _transAnim.value;
                      return Opacity(
                        opacity: ((1.0 - tTrans) * tLogin).clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: tLogin < 0.95 || tTrans > 0.05,
                          child: child!,
                        ),
                      );
                    },
                    child: const MapScreen(),
                  ),
                ),

                // ── Layer 2: PuzzleBoard — slides up from below as tTrans → 1
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: _transAnim,
                    builder: (ctx, child) {
                      final t = _transAnim.value;
                      final dy = lerpDouble(s.height, _gridHeaderH, t)!;
                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: IgnorePointer(
                          ignoring: t < 0.92,
                          child: child!,
                        ),
                      );
                    },
                    child: const PuzzleBoard(),
                  ),
                ),

                // ── Layer 3: Pentagram overlay — persistent, animated pos ────
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: Listenable.merge(
                        [_transAnim, _threadCtrl, _elapsedNotifier, _loginAnim]),
                    builder: (ctx, _) {
                      final t = _transAnim.value;
                      final tLogin = _loginAnim.value;
                      final state =
                          Provider.of<GridState>(ctx, listen: false);
                      final isGridMode = t > 0.5;

                      // Interpolated pentagram geometry
                      final center = Offset.lerp(
                          _mapCenter(s), _gridCenter(s), t)!;
                      final radius = lerpDouble(
                          _mapRadius(s), _gridLayoutR, t)!;
                      final nodeR =
                          lerpDouble(_mapNodeR, _gridNodeR, t)!;
                      final coreR =
                          lerpDouble(_mapCoreR, _gridCoreR, t)!;
                      final cPos =
                          _computeConceptPositions(center, radius);

                      return Opacity(
                        opacity: tLogin.clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: tLogin < 0.95,
                          child: Stack(
                            children: [
                              IgnorePointer(
                                ignoring: true,
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: PentagramPainter(
                                      conceptPositions: cPos,
                                      center: center,
                                      activeEndings: state.activeEndingSet,
                                      unlockOrder: state.unlockOrder,
                                      animProgress: _threadCtrl.value,
                                      showCore: state.allEndingsUnlocked,
                                      hoveredId: _hoveredPentagramId,
                                      elapsed: _elapsed,
                                      activeToolIndex: state.activeTool,
                                      nodeRadius: nodeR,
                                      coreRadius: coreR,
                                    ),
                                    size: s,
                                  ),
                                ),
                              ),
                              if (state.allEndingsUnlocked)
                                Positioned(
                                  left: center.dx - (coreR + 10),
                                  top: center.dy - (coreR + 10),
                                  width: (coreR + 10) * 2,
                                  height: (coreR + 10) * 2,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(() {
                                      _hoveredPentagramId = kCoreNodeId;
                                    }),
                                    onExit: (_) => setState(() {
                                      _hoveredPentagramId = null;
                                    }),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        state.setScreen(isGridMode ? 0 : 1);
                                      },
                                    ),
                                  ),
                                ),
                              ...cPos.entries.map((entry) {
                                final String concept = entry.key;
                                final Offset pos = entry.value;
                                final bool isActive = state.isEndingActive(concept);
                                final bool isInteractive = isGridMode && isActive;

                                if (!isInteractive) return const SizedBox.shrink();

                                return Positioned(
                                  left: pos.dx - (nodeR + 8),
                                  top: pos.dy - (nodeR + 8),
                                  width: (nodeR + 8) * 2,
                                  height: (nodeR + 8) * 2,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(() {
                                      _hoveredPentagramId = concept;
                                    }),
                                    onExit: (_) => setState(() {
                                      _hoveredPentagramId = null;
                                    }),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        const tMap = {'c1': 1, 'c2': 2, 'c3': 3, 'c4': 4, 'c5': 5};
                                        state.setActiveTool(tMap[concept] ?? 0);
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Layer 4: Dev Auto-Complete FAB (bottom-right) ─────────────
                Positioned(
                  bottom: 24.0,
                  right: 24.0,
                  child: ListenableBuilder(
                    listenable: _loginAnim,
                    builder: (ctx, child) {
                      return Opacity(
                        opacity: _loginAnim.value.clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: _loginAnim.value < 0.95,
                          child: child!,
                        ),
                      );
                    },
                    child: _DevAutoCompleteFAB(
                      onTap: () => Provider.of<GridState>(context, listen: false)
                          .devAutoComplete(),
                    ),
                  ),
                ),

                // ── Layer 5: Morphing Login / Code Input Bar ─────────────────
                ListenableBuilder(
                  listenable: Listenable.merge([_loginAnim, _transAnim, _shakeAnim]),
                  builder: (ctx, _) {
                    return MorphingInputBar(
                      loginAnim: _loginAnim,
                      transAnim: _transAnim,
                      shakeAnim: _shakeAnim,
                      screenSize: s,
                      onLoginSuccess: () {
                        _loginCtrl.forward();
                      },
                      onShake: () {
                        _shakeCtrl.forward(from: 0.0);
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _DevAutoCompleteFAB — DEV ONLY: instantly activates all 5 endings
// ═══════════════════════════════════════════════════════════════════════════
class _DevAutoCompleteFAB extends StatefulWidget {
  final VoidCallback onTap;
  const _DevAutoCompleteFAB({required this.onTap});

  @override
  State<_DevAutoCompleteFAB> createState() => _DevAutoCompleteFABState();
}

class _DevAutoCompleteFABState extends State<_DevAutoCompleteFAB> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding:
              const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHigh : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_fix_high_rounded,
                color: AppColors.textMuted,
                size: 14.0,
              ),
              const SizedBox(width: 7.0),
              Text(
                'Auto Complete',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

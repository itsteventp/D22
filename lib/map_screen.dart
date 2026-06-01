import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'grid_state.dart';
import 'map_physics.dart';
import 'theme.dart';
import 'widgets/blob_painter.dart';
import 'widgets/void_background_painter.dart';

// ---------------------------------------------------------------------------
// MapScreen — void canvas + floating blob physics + code input.
// The pentagram is no longer rendered here; it lives as a persistent overlay
// in MainNavigator and animates between the map-center and grid-header positions.
// ---------------------------------------------------------------------------
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // ── Input ──────────────────────────────────────────────────────────────────
  final TextEditingController _codeCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  // ── Physics ────────────────────────────────────────────────────────────────
  late final Ticker _physicsTicker;
  final BlobPhysicsSimulator _physics = BlobPhysicsSimulator();
  final ValueNotifier<double> _physicsTime = ValueNotifier(0.0);
  double _elapsed = 0.0;
  DateTime _lastTick = DateTime.now();
  Size _canvasSize = const Size(800, 600);

  // ── Blob interaction ───────────────────────────────────────────────────────
  String? _hoveredBlobId;
  String? _draggedBlobId;
  SystemMouseCursor _cursor = SystemMouseCursors.basic;

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _physicsTicker = createTicker(_onPhysicsTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<GridState>(context, listen: false).fetchMasterConnections();
      }
    });
  }

  void _onPhysicsTick(Duration _) {
    if (!mounted) return;
    final now = DateTime.now();
    final dt =
        (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = now;
    _elapsed += dt;

    final state = Provider.of<GridState>(context, listen: false);
    _physics.sync(state.nodes, _canvasSize);
    _physics.step(_elapsed, _canvasSize);
    _physicsTime.value = _elapsed;
  }

  @override
  void dispose() {
    _physicsTicker.dispose();
    _physicsTime.dispose();
    _codeCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Hit-testing
  // ══════════════════════════════════════════════════════════════════════════
  String? _hitTestBlob(Offset pos, GridState state) {
    for (final node in state.nodes.reversed) {
      final phys = _physics.get(node.id);
      if (phys == null) continue;
      if ((pos - phys.position).distance <= phys.radius + 8) return node.id;
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Gestures (blob only)
  // ══════════════════════════════════════════════════════════════════════════
  void _handlePanStart(DragStartDetails details) {
    final state = Provider.of<GridState>(context, listen: false);
    final hit = _hitTestBlob(details.localPosition, state);
    if (hit != null) {
      _draggedBlobId = hit;
      _cursor = SystemMouseCursors.grabbing;
      _physics.pinNode(hit, details.localPosition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggedBlobId != null) {
      _physics.moveNode(_draggedBlobId!, details.localPosition);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedBlobId != null) {
      final vel = details.velocity.pixelsPerSecond / 60.0;
      _physics.releaseNode(_draggedBlobId!, vel);
      _draggedBlobId = null;
      _cursor = SystemMouseCursors.basic;
    }
  }

  void _handleHover(PointerHoverEvent event) {
    final state = Provider.of<GridState>(context, listen: false);
    final hit = _hitTestBlob(event.localPosition, state);
    final newCursor =
        hit != null ? SystemMouseCursors.grab : SystemMouseCursors.basic;
    if (hit != _hoveredBlobId || newCursor != _cursor) {
      setState(() {
        _hoveredBlobId = hit;
        _cursor = newCursor;
      });
    }
  }

  void _handleHoverExit(PointerExitEvent _) {
    if (_hoveredBlobId != null || _cursor != SystemMouseCursors.basic) {
      setState(() {
        _hoveredBlobId = null;
        _cursor = SystemMouseCursors.basic;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Column(
      children: [
        // ── Code input bar ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 10.0),
          child: _InputBar(
            controller: _codeCtrl,
            focusNode: _inputFocus,
            onSubmit: () {
              state.submitCode(_codeCtrl.text, context);
              _codeCtrl.clear();
            },
          ),
        ),

        // ── Canvas ──────────────────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              _canvasSize =
                  Size(constraints.maxWidth, constraints.maxHeight);

              return Stack(
                children: [
                  // Layer 1: Static void background
                  RepaintBoundary(
                    child: SizedBox.expand(
                      child: CustomPaint(
                          painter: const VoidBackgroundPainter()),
                    ),
                  ),

                  // Layer 2: Blob physics canvas (rerenders every tick)
                  ListenableBuilder(
                    listenable: _physicsTime,
                    builder: (ctx, _) {
                      final s =
                          Provider.of<GridState>(ctx, listen: false);
                      return RepaintBoundary(
                        child: SizedBox.expand(
                          child: CustomPaint(
                            painter: BlobCanvasPainter(
                              nodes: s.nodes,
                              connections: s.connections,
                              physics: _physics,
                              hoveredNodeId: _hoveredBlobId,
                              draggedNodeId: _draggedBlobId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Layer 3: Gesture + hover (transparent, on top)
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: _cursor,
                      onHover: _handleHover,
                      onExit: _handleHoverExit,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _handlePanStart,
                        onPanUpdate: _handlePanUpdate,
                        onPanEnd: _handlePanEnd,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _InputBar
// ═══════════════════════════════════════════════════════════════════════════
class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(
        () => mounted ? setState(() => _focused = widget.focusNode.hasFocus) : null);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.normal,
      height: 48.0,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.textMuted.withValues(alpha: 0.28),
                  blurRadius: 20,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16.0),
          Icon(
            Icons.terminal_rounded,
            size: 16.0,
            color: _focused
                ? AppColors.textSecondary
                : AppColors.textMuted,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: AppTextStyles.code(
                  color: AppColors.textPrimary, size: 13.5),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter code...',
                hintStyle: AppTextStyles.code(
                    color: AppColors.textMuted, size: 13.5),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => widget.onSubmit(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: _SubmitButton(onPressed: widget.onSubmit),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _SubmitButton
// ═══════════════════════════════════════════════════════════════════════════
class _SubmitButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _SubmitButton({required this.onPressed});

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.textPrimary
                : AppColors.textPrimary.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.22),
                      blurRadius: 14,
                    ),
                  ]
                : [],
          ),
          child: Text(
            'Unlock',
            style: GoogleFonts.inter(
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}

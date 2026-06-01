import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'grid_state.dart';
import 'map_node.dart';
import 'map_physics.dart';
import 'theme.dart';
import 'widgets/blob_painter.dart';
import 'widgets/void_background_painter.dart';

// ---------------------------------------------------------------------------
// MapScreen — infinite-void blob canvas with physics simulation
// ---------------------------------------------------------------------------
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  late final Ticker _ticker;
  final BlobPhysicsSimulator _physics = BlobPhysicsSimulator();

  // Hover / drag tracking (canvas-level)
  String? _hoveredNodeId;
  String? _draggedNodeId;

  // Elapsed time for wobble animation
  double _elapsed = 0.0;
  DateTime _lastTick = DateTime.now();

  // Canvas size captured from LayoutBuilder
  Size _canvasSize = const Size(800, 600);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<GridState>(context, listen: false).fetchMasterConnections();
      }
    });
  }

  void _onTick(Duration _) {
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMilliseconds / 1000.0;
    _lastTick = now;
    _elapsed += dt;

    final state = Provider.of<GridState>(context, listen: false);

    // Sync physics with current nodes
    _physics.sync(state.nodes, _canvasSize);

    // Step physics
    _physics.step(_elapsed, _canvasSize);

    // Write physics positions back to state (for connection painter)
    for (final phys in _physics.all) {
      state.updateNodePosition(phys.nodeId, phys.position);
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _codeController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Hit test — find blob at pointer
  // ---------------------------------------------------------------------------
  String? _nodeAt(Offset localPos) {
    final state = Provider.of<GridState>(context, listen: false);
    for (final node in state.nodes.reversed) {
      final phys = _physics.get(node.id);
      if (phys == null) continue;
      if ((localPos - phys.position).distance <= phys.radius + 8) {
        return node.id;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Column(
      children: [
        // ── Input bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
          child: _InputBar(
            controller: _codeController,
            focusNode: _inputFocus,
            onSubmit: () {
              state.submitCode(_codeController.text, context);
              _codeController.clear();
            },
          ),
        ),

        // ── Canvas ────────────────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

              return Selector<GridState, _MapData>(
                selector: (_, s) => _MapData(
                  List.from(s.nodes),
                  List.from(s.connections),
                ),
                shouldRebuild: (a, b) => true, // ticker drives this
                builder: (context, data, _) {
                  return MouseRegion(
                    onHover: (event) {
                      final hit = _nodeAt(event.localPosition);
                      if (hit != _hoveredNodeId) {
                        setState(() => _hoveredNodeId = hit);
                      }
                    },
                    onExit: (_) => setState(() => _hoveredNodeId = null),
                    cursor: _hoveredNodeId != null
                        ? SystemMouseCursors.grab
                        : SystemMouseCursors.basic,
                    child: GestureDetector(
                      onPanStart: (details) {
                        final hit = _nodeAt(details.localPosition);
                        if (hit != null) {
                          _draggedNodeId = hit;
                          _physics.pinNode(hit, details.localPosition);
                        }
                      },
                      onPanUpdate: (details) {
                        if (_draggedNodeId != null) {
                          _physics.moveNode(
                              _draggedNodeId!, details.localPosition);
                        }
                      },
                      onPanEnd: (details) {
                        if (_draggedNodeId != null) {
                          final vel = details.velocity.pixelsPerSecond / 60.0;
                          _physics.releaseNode(_draggedNodeId!, vel);
                          _draggedNodeId = null;
                        }
                      },
                      child: CustomPaint(
                        painter: const VoidBackgroundPainter(),
                        foregroundPainter: BlobCanvasPainter(
                          nodes: data.nodes,
                          connections: data.connections,
                          physics: _physics,
                          hoveredNodeId: _hoveredNodeId,
                          draggedNodeId: _draggedNodeId,
                        ),
                        size: _canvasSize,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Selector data wrapper
// ---------------------------------------------------------------------------
class _MapData {
  final List<MapNode> nodes;
  final List<MapConnection> connections;
  _MapData(this.nodes, this.connections);
}

// ---------------------------------------------------------------------------
// _InputBar — glassmorphic, borderless input with glowing submit button
// ---------------------------------------------------------------------------
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
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
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
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16.0),
          // Icon
          Icon(
            Icons.terminal_rounded,
            size: 16.0,
            color: _focused ? AppColors.textSecondary : AppColors.textMuted,
          ),
          const SizedBox(width: 10.0),
          // Text field
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: AppTextStyles.code(
                color: AppColors.textPrimary,
                size: 13.5,
              ),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter code...',
                hintStyle: AppTextStyles.code(
                  color: AppColors.textMuted,
                  size: 13.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => widget.onSubmit(),
            ),
          ),
          // Submit button
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: _SubmitButton(onPressed: widget.onSubmit),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SubmitButton — glowing pill button
// ---------------------------------------------------------------------------
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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
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
                      color: AppColors.textPrimary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 0,
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

// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'grid_state.dart';
import 'map_physics.dart';
import 'widgets/blob_painter.dart';

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
    return LayoutBuilder(
      builder: (ctx, constraints) {
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            // Layer 2: Blob physics canvas (rerenders every tick)
            ListenableBuilder(
              listenable: _physicsTime,
              builder: (ctx, _) {
                final s = Provider.of<GridState>(ctx, listen: false);
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
    );
  }
}

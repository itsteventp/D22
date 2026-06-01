import 'dart:math';
import 'package:flutter/material.dart';
import 'map_node.dart';

// ---------------------------------------------------------------------------
// MapNodePhysics — runtime physics wrapper for a single blob
// ---------------------------------------------------------------------------
class MapNodePhysics {
  final String nodeId;

  // Position is kept in sync with GridState.nodes, but physics drives it
  Offset position;
  Offset velocity;

  // Blob visual radius — derived from title length
  double radius;

  // Per-node randomised offsets for idle wobble
  final double wobbleSeedX;
  final double wobbleSeedY;

  // When true the blob is being dragged — skip physics forces
  bool isPinned;

  // Spawn scale animation progress [0..1]
  double spawnScale;
  bool isSpawning;

  MapNodePhysics({
    required this.nodeId,
    required this.position,
    required this.radius,
  })  : velocity = Offset.zero,
        wobbleSeedX = Random().nextDouble() * 2 * pi,
        wobbleSeedY = Random().nextDouble() * 2 * pi,
        isPinned = false,
        spawnScale = 0.0,
        isSpawning = true;
}

// ---------------------------------------------------------------------------
// BlobPhysicsSimulator — owns all runtime node physics, stepped per frame
// ---------------------------------------------------------------------------
class BlobPhysicsSimulator {
  final Map<String, MapNodePhysics> _physics = {};

  static const double _damping        = 0.88;
  static const double _repulsionForce = 18000.0;
  static const double _gravityStrength = 0.04;
  static const double _wobbleAmp      = 0.4;
  static const double _spawnSpeed     = 0.08; // per frame ~5 frames to reach 1

  // ---------------------------------------------------------------------------
  // Sync nodes: add new nodes, remove stale ones
  // ---------------------------------------------------------------------------
  void sync(List<MapNode> nodes, Size canvasSize) {
    // Add new
    for (final node in nodes) {
      if (!_physics.containsKey(node.id)) {
        final radius = _radiusForTitle(node.title);
        _physics[node.id] = MapNodePhysics(
          nodeId: node.id,
          position: node.position,
          radius: radius,
        );
      } else {
        // If the node position was updated externally (drag pinned) sync it
        if (_physics[node.id]!.isPinned) {
          _physics[node.id]!.position = node.position;
        }
      }
    }

    // Remove stale
    final liveIds = nodes.map((n) => n.id).toSet();
    _physics.removeWhere((id, _) => !liveIds.contains(id));
  }

  // ---------------------------------------------------------------------------
  // Step simulation one frame
  // ---------------------------------------------------------------------------
  void step(double elapsedSeconds, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final t = elapsedSeconds;
    final all = _physics.values.toList();

    for (final node in all) {
      // Spawn-in animation
      if (node.isSpawning) {
        node.spawnScale = (node.spawnScale + _spawnSpeed).clamp(0.0, 1.0);
        if (node.spawnScale >= 1.0) node.isSpawning = false;
      }

      if (node.isPinned) continue;

      // 1. Idle wobble (sin-based drift)
      final wx = sin(t * 0.7 + node.wobbleSeedX) * _wobbleAmp;
      final wy = cos(t * 0.5 + node.wobbleSeedY) * _wobbleAmp;
      node.velocity += Offset(wx, wy);

      // 2. Soft gravity toward canvas center
      final toCenter = center - node.position;
      final dist = toCenter.distance;
      if (dist > 1.0) {
        node.velocity += toCenter / dist * _gravityStrength * dist.clamp(0, 300) / 100;
      }

      // 3. Node-to-node repulsion
      for (final other in all) {
        if (other.nodeId == node.nodeId || other.isPinned) continue;
        final delta = node.position - other.position;
        final d = delta.distance;
        final minDist = node.radius + other.radius + 20.0;
        if (d > 0 && d < minDist * 2.5) {
          final force = _repulsionForce / (d * d + 1.0);
          node.velocity += delta / d * force;
        }
      }

      // 4. Boundary bounce (soft — push back when near edges)
      const margin = 80.0;
      if (node.position.dx < margin) node.velocity += Offset((margin - node.position.dx) * 0.15, 0);
      if (node.position.dy < margin) node.velocity += Offset(0, (margin - node.position.dy) * 0.15);
      if (node.position.dx > canvasSize.width - margin) node.velocity += Offset((canvasSize.width - margin - node.position.dx) * 0.15, 0);
      if (node.position.dy > canvasSize.height - margin) node.velocity += Offset(0, (canvasSize.height - margin - node.position.dy) * 0.15);

      // 5. Damping
      node.velocity *= _damping;

      // 6. Integrate
      node.position += node.velocity;
    }
  }

  // ---------------------------------------------------------------------------
  // Interaction helpers
  // ---------------------------------------------------------------------------
  void pinNode(String id, Offset position) {
    final p = _physics[id];
    if (p != null) {
      p.isPinned = true;
      p.velocity = Offset.zero;
      p.position = position;
    }
  }

  void moveNode(String id, Offset position) {
    final p = _physics[id];
    if (p != null) p.position = position;
  }

  void releaseNode(String id, Offset velocity) {
    final p = _physics[id];
    if (p != null) {
      p.isPinned = false;
      p.velocity = velocity;
    }
  }

  // ---------------------------------------------------------------------------
  // Query
  // ---------------------------------------------------------------------------
  MapNodePhysics? get(String id) => _physics[id];
  List<MapNodePhysics> get all => _physics.values.toList();

  // ---------------------------------------------------------------------------
  // Radius from title length
  // ---------------------------------------------------------------------------
  static double _radiusForTitle(String title) {
    return (32.0 + title.length * 2.5).clamp(36.0, 64.0);
  }
}

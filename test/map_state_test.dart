import 'package:flutter_test/flutter_test.dart';
import 'package:d22/grid_state.dart';
import 'package:d22/map_node.dart';
import 'package:flutter/material.dart';

void main() {
  group('GridState Map Screen Tests', () {
    test('Initialization starts with empty nodes and connections lists', () {
      final state = GridState();
      expect(state.nodes.isEmpty, isTrue);
      expect(state.connections.isEmpty, isTrue);
    });

    test('updateNodePosition changes coordinates of a manually added node', () {
      final state = GridState();
      
      final node = MapNode(
        id: 'node_A',
        position: const Offset(150.0, 150.0),
        color: Colors.purple,
        title: 'Alpha',
      );
      state.addNodeForTesting(node);
      expect(state.nodes.length, 1);

      final targetPos = const Offset(200.0, 200.0);
      state.updateNodePosition('node_A', targetPos);

      expect(state.nodes[0].position, targetPos);
    });

    test('addNodeForTesting automatically draws connections based on master connections list', () {
      final state = GridState();
      
      // Mock master connections list
      state.setMasterConnectionsForTesting([
        {'from_item': 'item-y64apgh2', 'to_item': 'item-vbhlkq4m'}
      ]);
      
      final nodeA = MapNode(
        id: 'item-y64apgh2',
        position: const Offset(100, 100),
        color: Colors.blue,
        title: 'Source',
      );
      final nodeB = MapNode(
        id: 'item-vbhlkq4m',
        position: const Offset(200, 200),
        color: Colors.red,
        title: 'Destination',
      );

      state.addNodeForTesting(nodeA);
      expect(state.connections.isEmpty, isTrue); // no peer yet

      state.addNodeForTesting(nodeB);
      expect(state.connections.length, 1); // connected!
      expect(state.connections[0].fromId, 'item-vbhlkq4m');
      expect(state.connections[0].toId, 'item-y64apgh2');
    });

    test('setScreen updates active screen index', () {
      final state = GridState();
      expect(state.currentScreen, 0); // starts at Map

      state.setScreen(1);
      expect(state.currentScreen, 1); // switch to Grid

      state.setScreen(9); // invalid value
      expect(state.currentScreen, 1); // unchanged
    });
  });
}

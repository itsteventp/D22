import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'grid_state.dart';
import 'map_node.dart';

// Helper class for lines repaint selector
class MapLinesData {
  final List<MapNode> nodes;
  final List<MapConnection> connections;

  MapLinesData(this.nodes, this.connections);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MapLinesData) return false;

    if (nodes.length != other.nodes.length || connections.length != other.connections.length) {
      return false;
    }

    // Check positions of all nodes
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].id != other.nodes[i].id || nodes[i].position != other.nodes[i].position) {
        return false;
      }
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(nodes.length, connections.length);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<GridState>(context, listen: false).fetchMasterConnections();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Column(
      children: [
        // Top Control Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: const Color(0xFF27272A),
                    ),
                  ),
                  child: TextField(
                    controller: _codeController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.0,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      hintText: "Enter Code...",
                      hintStyle: TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 13.0,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              SizedBox(
                height: 40.0,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  onPressed: () {
                    state.submitCode(_codeController.text, context);
                    _codeController.clear();
                  },
                  child: const Text(
                    "Submit Code",
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Expansive Canvas Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: const Color(0xFF27272A),
              ),
            ),
            child: ClipRect(
              child: Stack(
                children: [
                  // 1. Connection lines (repaints dynamically on drag)
                  Selector<GridState, MapLinesData>(
                    selector: (_, s) => MapLinesData(List.from(s.nodes), List.from(s.connections)),
                    builder: (context, data, _) {
                      return RepaintBoundary(
                        child: CustomPaint(
                          painter: ConnectionsPainter(data),
                          child: Container(),
                        ),
                      );
                    },
                  ),

                  // 2. Interactive Map Nodes
                  Selector<GridState, List<String>>(
                    selector: (_, s) => s.nodes.map((n) => n.id).toList(),
                    builder: (context, nodeIds, _) {
                      return Stack(
                        children: nodeIds.map((id) {
                          return PositionedNodeWidget(nodeId: id);
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- CONNECTION LINES CUSTOM PAINTER ---
class ConnectionsPainter extends CustomPainter {
  final MapLinesData data;

  ConnectionsPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF27272A) // Zinc 800 grey line
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final connection in data.connections) {
      final fromNode = _findNode(connection.fromId);
      final toNode = _findNode(connection.toId);

      if (fromNode != null && toNode != null) {
        // Draw line between centers of the nodes (approx offset)
        // Adjust for node visual dimensions: w = 120, h = 40 (center is at +60, +20)
        final fromCenter = fromNode.position + const Offset(60.0, 20.0);
        final toCenter = toNode.position + const Offset(60.0, 20.0);

        canvas.drawLine(fromCenter, toCenter, paint);
      }
    }
  }

  MapNode? _findNode(String id) {
    try {
      return data.nodes.firstWhere((node) => node.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionsPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

// --- POSITIONED NODE WIDGET (TARGETED REBUILD PER NODE ID) ---
class PositionedNodeWidget extends StatelessWidget {
  final String nodeId;

  const PositionedNodeWidget({
    super.key,
    required this.nodeId,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Selector<GridState, MapNode>(
      selector: (_, s) => s.nodes.firstWhere((n) => n.id == nodeId),
      builder: (context, node, _) {
        return Positioned(
          left: node.position.dx,
          top: node.position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              state.updateNodePosition(node.id, node.position + details.delta);
            },
            child: RepaintBoundary(
              child: Container(
                width: 120.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: const Color(0xFF27272A),
                    width: 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                    // Color strip accent on left edge
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3.0,
                        decoration: BoxDecoration(
                          color: node.color,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6.0),
                            bottomLeft: Radius.circular(6.0),
                          ),
                        ),
                      ),
                    ),

                    // Label
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Text(
                          node.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

class MapNode {
  final String id;
  final Offset position;
  final Color color;
  final String title;

  MapNode({
    required this.id,
    required this.position,
    required this.color,
    required this.title,
  });

  MapNode copyWith({
    String? id,
    Offset? position,
    Color? color,
    String? title,
  }) {
    return MapNode(
      id: id ?? this.id,
      position: position ?? this.position,
      color: color ?? this.color,
      title: title ?? this.title,
    );
  }
}

class MapConnection {
  final String fromId;
  final String toId;

  MapConnection({
    required this.fromId,
    required this.toId,
  });
}

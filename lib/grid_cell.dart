import 'package:flutter/material.dart';

class GridCell {
  final String id;
  final int currentCol;
  final int currentRow;
  final String codeText;
  final Color color;
  final String secretLetter;

  GridCell({
    required this.id,
    required this.currentCol,
    required this.currentRow,
    required this.codeText,
    required this.color,
    required this.secretLetter,
  });

  GridCell copyWith({
    String? id,
    int? currentCol,
    int? currentRow,
    String? codeText,
    Color? color,
    String? secretLetter,
  }) {
    return GridCell(
      id: id ?? this.id,
      currentCol: currentCol ?? this.currentCol,
      currentRow: currentRow ?? this.currentRow,
      codeText: codeText ?? this.codeText,
      color: color ?? this.color,
      secretLetter: secretLetter ?? this.secretLetter,
    );
  }
}

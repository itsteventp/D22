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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'currentCol': currentCol,
      'currentRow': currentRow,
      'codeText': codeText,
      'colorHex': color.toARGB32().toRadixString(16),
      'secretLetter': secretLetter,
    };
  }

  factory GridCell.fromJson(Map<String, dynamic> json) {
    return GridCell(
      id: json['id'] as String,
      currentCol: json['currentCol'] as int,
      currentRow: json['currentRow'] as int,
      codeText: json['codeText'] as String,
      color: Color(int.parse(json['colorHex'] as String, radix: 16)),
      secretLetter: json['secretLetter'] as String,
    );
  }
}

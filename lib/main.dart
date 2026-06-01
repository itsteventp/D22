import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'grid_state.dart';
import 'puzzle_board.dart';

void main() {
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
      title: 'ARG Grid Puzzle Decryptor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        fontFamily: 'monospace',
      ),
      home: const PuzzleBoard(),
    );
  }
}

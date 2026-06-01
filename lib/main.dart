import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grid_state.dart';
import 'puzzle_board.dart';
import 'map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://pvsnqcnpunhuxquhlcld.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2c25xY25wdW5odXhxdWhsY2xkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNzkwMDksImV4cCI6MjA5NTg1NTAwOX0.kflbafAlRmpLEhAEU2isJKSJATtsMeAQ9ZUvWCnubFU',
  );

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
      title: 'ARG Decryptor System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.grey,
        fontFamily: 'monospace',
      ),
      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatelessWidget {
  const MainNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B), // Zinc 950
      body: SafeArea(
        child: Column(
          children: [
            // Global Screen Toggle (Tab selection)
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
              child: Selector<GridState, int>(
                selector: (_, s) => s.currentScreen,
                builder: (context, currentScreen, _) {
                  return Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B), // Zinc 900
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: const Color(0xFF27272A), // Zinc 800
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabButton(context, 0, "Phase 1: Map", currentScreen == 0, state),
                        const SizedBox(width: 4.0),
                        _buildTabButton(context, 1, "Phase 2: Grid", currentScreen == 1, state),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Active Screen Content
            Expanded(
              child: Selector<GridState, int>(
                selector: (_, s) => s.currentScreen,
                builder: (context, currentScreen, _) {
                  if (currentScreen == 0) {
                    return const MapScreen();
                  } else {
                    return const PuzzleBoard();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, int index, String label, bool isSelected, GridState state) {
    return GestureDetector(
      onTap: () => state.setScreen(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF09090B) : Colors.transparent, // Zinc 950
          borderRadius: BorderRadius.circular(6.0),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF27272A),
                  width: 1.0,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

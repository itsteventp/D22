import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'grid_state.dart';
import 'puzzle_board.dart';
import 'map_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pvsnqcnpunhuxquhlcld.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2c25xY25wdW5odXhxdWhsY2xkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNzkwMDksImV4cCI6MjA5NTg1NTAwOX0.kflbafAlRmpLEhAEU2isJKSJATtsMeAQ9ZUvWCnubFU',
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
      theme: buildAppTheme(),
      home: const MainNavigator(),
    );
  }
}

// ---------------------------------------------------------------------------
// MainNavigator — floating tab bar + screen switcher
// ---------------------------------------------------------------------------
class MainNavigator extends StatelessWidget {
  const MainNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GridState>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Floating pill tab bar
            Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 6.0),
              child: Selector<GridState, int>(
                selector: (_, s) => s.currentScreen,
                builder: (context, currentScreen, _) {
                  return _AppTabBar(
                    currentScreen: currentScreen,
                    onTap: state.setScreen,
                  );
                },
              ),
            ),

            // Active screen
            Expanded(
              child: Selector<GridState, int>(
                selector: (_, s) => s.currentScreen,
                builder: (context, currentScreen, _) {
                  return AnimatedSwitcher(
                    duration: AppDurations.medium,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: currentScreen == 0
                        ? const MapScreen(key: ValueKey('map'))
                        : const PuzzleBoard(key: ValueKey('grid')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AppTabBar — pill-style floating selector
// ---------------------------------------------------------------------------
class _AppTabBar extends StatelessWidget {
  final int currentScreen;
  final void Function(int) onTap;

  const _AppTabBar({required this.currentScreen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
        children: [
          // Sliding active indicator
          AnimatedAlign(
            duration: AppDurations.normal,
            curve: Curves.easeInOutCubic,
            alignment: currentScreen == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 34.0,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          // Tab buttons (on top of indicator)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabButton(
                label: 'Phase 1 · Map',
                isSelected: currentScreen == 0,
                onTap: () => onTap(0),
              ),
              _TabButton(
                label: 'Phase 2 · Grid',
                isSelected: currentScreen == 1,
                onTap: () => onTap(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 140.0,
        height: 34.0,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppDurations.fast,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
